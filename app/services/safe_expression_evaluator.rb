# SafeExpressionEvaluator
# Safely evaluates mathematical and logical expressions without using eval()
# Prevents code injection by using a proper parser and whitelist approach
class SafeExpressionEvaluator
  class ExpressionError < StandardError; end
  
  ALLOWED_OPERATORS = {
    '+' => :add,
    '-' => :subtract,
    '*' => :multiply,
    '/' => :divide,
    '%' => :modulo,
    '**' => :power,
    '==' => :equals,
    '!=' => :not_equals,
    '>' => :greater_than,
    '<' => :less_than,
    '>=' => :greater_or_equal,
    '<=' => :less_or_equal,
    '&&' => :logical_and,
    '||' => :logical_or,
    '!' => :logical_not
  }.freeze
  
  ALLOWED_FUNCTIONS = {
    'abs' => ->(x) { x.abs },
    'round' => ->(x, precision = 0) { x.round(precision) },
    'ceil' => ->(x) { x.ceil },
    'floor' => ->(x) { x.floor },
    'sqrt' => ->(x) { Math.sqrt(x) },
    'min' => ->(*args) { args.min },
    'max' => ->(*args) { args.max },
    'sum' => ->(*args) { args.sum },
    'avg' => ->(*args) { args.sum.to_f / args.length },
    'concat' => ->(*args) { args.join },
    'upper' => ->(str) { str.to_s.upcase },
    'lower' => ->(str) { str.to_s.downcase },
    'trim' => ->(str) { str.to_s.strip },
    'length' => ->(obj) { obj.respond_to?(:length) ? obj.length : 0 },
    'now' => -> { Time.current },
    'today' => -> { Date.current },
    'year' => ->(date) { Date.parse(date.to_s).year rescue nil },
    'month' => ->(date) { Date.parse(date.to_s).month rescue nil },
    'day' => ->(date) { Date.parse(date.to_s).day rescue nil }
  }.freeze
  
  def self.evaluate(expression, context = {})
    new(expression, context).evaluate
  end
  
  def initialize(expression, context = {})
    @expression = expression.to_s.strip
    @context = context
    @tokens = []
    @position = 0
  end
  
  def evaluate
    return nil if @expression.empty?
    
    # First check if it's a simple numeric expression
    if @expression.match?(/^[\d\s\+\-\*\/\(\)\.]+$/)
      evaluate_arithmetic(@expression)
    else
      # Parse and evaluate more complex expressions
      tokenize
      parse_expression
    end
  rescue => e
    raise ExpressionError, "Failed to evaluate expression: #{e.message}"
  end
  
  private
  
  def evaluate_arithmetic(expr)
    # Remove spaces and validate characters
    clean_expr = expr.gsub(/\s+/, '')
    
    # Validate that only allowed characters are present
    unless clean_expr.match?(/^[\d\+\-\*\/\(\)\.]+$/)
      raise ExpressionError, "Invalid characters in arithmetic expression"
    end
    
    # Parse and calculate using a safe recursive descent parser
    tokens = tokenize_arithmetic(clean_expr)
    evaluate_arithmetic_tokens(tokens)
  end
  
  def tokenize_arithmetic(expr)
    tokens = []
    current_number = ''
    
    expr.each_char.with_index do |char, i|
      case char
      when /[\d\.]/
        current_number += char
      when /[\+\-\*\/\(\)]/
        if current_number.present?
          tokens << { type: :number, value: current_number.include?('.') ? current_number.to_f : current_number.to_i }
          current_number = ''
        end
        tokens << { type: :operator, value: char }
      else
        raise ExpressionError, "Invalid character: #{char}"
      end
    end
    
    if current_number.present?
      tokens << { type: :number, value: current_number.include?('.') ? current_number.to_f : current_number.to_i }
    end
    
    tokens
  end
  
  def evaluate_arithmetic_tokens(tokens)
    # Simple shunting-yard algorithm for safe evaluation
    output_queue = []
    operator_stack = []
    
    precedence = { '+' => 1, '-' => 1, '*' => 2, '/' => 2 }
    
    tokens.each do |token|
      case token[:type]
      when :number
        output_queue << token[:value]
      when :operator
        if token[:value] == '('
          operator_stack << token[:value]
        elsif token[:value] == ')'
          while operator_stack.last != '('
            apply_operator(output_queue, operator_stack.pop)
          end
          operator_stack.pop # Remove the '('
        else
          while operator_stack.any? && 
                operator_stack.last != '(' && 
                precedence[operator_stack.last].to_i >= precedence[token[:value]].to_i
            apply_operator(output_queue, operator_stack.pop)
          end
          operator_stack << token[:value]
        end
      end
    end
    
    while operator_stack.any?
      apply_operator(output_queue, operator_stack.pop)
    end
    
    output_queue.first
  end
  
  def apply_operator(queue, operator)
    return if operator == '(' || operator == ')'
    
    right = queue.pop
    left = queue.pop
    
    raise ExpressionError, "Invalid expression" if right.nil? || left.nil?
    
    result = case operator
    when '+'
      left + right
    when '-'
      left - right
    when '*'
      left * right
    when '/'
      raise ExpressionError, "Division by zero" if right == 0
      left.to_f / right
    else
      raise ExpressionError, "Unknown operator: #{operator}"
    end
    
    queue << result
  end
  
  def tokenize
    # Tokenize more complex expressions with variables and functions
    @tokens = []
    scanner = StringScanner.new(@expression)
    
    until scanner.eos?
      # Skip whitespace
      scanner.scan(/\s+/)
      
      # Numbers
      if scanner.scan(/\d+\.?\d*/)
        @tokens << { type: :number, value: scanner.matched.include?('.') ? scanner.matched.to_f : scanner.matched.to_i }
      # Strings
      elsif scanner.scan(/"([^"]*)"/)
        @tokens << { type: :string, value: scanner[1] }
      elsif scanner.scan(/'([^']*)'/)
        @tokens << { type: :string, value: scanner[1] }
      # Variables (field references)
      elsif scanner.scan(/\{(\w+)\}/)
        @tokens << { type: :variable, value: scanner[1] }
      elsif scanner.scan(/\{\{(\w+)\}\}/)
        @tokens << { type: :variable, value: scanner[1] }
      # Functions
      elsif scanner.scan(/(\w+)\s*\(/)
        @tokens << { type: :function, value: scanner[1] }
        @tokens << { type: :lparen, value: '(' }
      # Operators
      elsif scanner.scan(/==|!=|>=|<=|&&|\|\||>>|<<|\*\*/)
        @tokens << { type: :operator, value: scanner.matched }
      elsif scanner.scan(/[\+\-\*\/%<>=!]/)
        @tokens << { type: :operator, value: scanner.matched }
      # Parentheses
      elsif scanner.scan(/\(/)
        @tokens << { type: :lparen, value: '(' }
      elsif scanner.scan(/\)/)
        @tokens << { type: :rparen, value: ')' }
      # Comma
      elsif scanner.scan(/,/)
        @tokens << { type: :comma, value: ',' }
      # Identifiers
      elsif scanner.scan(/\w+/)
        @tokens << { type: :identifier, value: scanner.matched }
      else
        raise ExpressionError, "Unexpected character: #{scanner.peek(1)}"
      end
    end
  end
  
  def parse_expression
    parse_logical_or
  end
  
  def parse_logical_or
    left = parse_logical_and
    
    while current_token && current_token[:value] == '||'
      consume(:operator)
      right = parse_logical_and
      left = left || right
    end
    
    left
  end
  
  def parse_logical_and
    left = parse_comparison
    
    while current_token && current_token[:value] == '&&'
      consume(:operator)
      right = parse_comparison
      left = left && right
    end
    
    left
  end
  
  def parse_comparison
    left = parse_additive
    
    if current_token && current_token[:type] == :operator && 
       %w[== != > < >= <=].include?(current_token[:value])
      op = consume(:operator)[:value]
      right = parse_additive
      
      left = case op
      when '==' then left == right
      when '!=' then left != right
      when '>' then left > right
      when '<' then left < right
      when '>=' then left >= right
      when '<=' then left <= right
      end
    end
    
    left
  end
  
  def parse_additive
    left = parse_multiplicative
    
    while current_token && current_token[:type] == :operator && 
          %w[+ -].include?(current_token[:value])
      op = consume(:operator)[:value]
      right = parse_multiplicative
      
      left = case op
      when '+' then left + right
      when '-' then left - right
      end
    end
    
    left
  end
  
  def parse_multiplicative
    left = parse_primary
    
    while current_token && current_token[:type] == :operator && 
          %w[* / %].include?(current_token[:value])
      op = consume(:operator)[:value]
      right = parse_primary
      
      left = case op
      when '*' then left * right
      when '/' 
        raise ExpressionError, "Division by zero" if right == 0
        left.to_f / right
      when '%' then left % right
      end
    end
    
    left
  end
  
  def parse_primary
    token = current_token
    
    case token[:type]
    when :number
      consume(:number)[:value]
    when :string
      consume(:string)[:value]
    when :variable
      var_name = consume(:variable)[:value]
      @context[var_name] || @context[var_name.to_sym] || 0
    when :function
      parse_function_call
    when :lparen
      consume(:lparen)
      result = parse_expression
      consume(:rparen)
      result
    when :operator
      if token[:value] == '-'
        consume(:operator)
        -parse_primary
      elsif token[:value] == '!'
        consume(:operator)
        !parse_primary
      else
        raise ExpressionError, "Unexpected operator: #{token[:value]}"
      end
    else
      raise ExpressionError, "Unexpected token: #{token.inspect}"
    end
  end
  
  def parse_function_call
    func_name = consume(:function)[:value]
    args = []
    
    # Already consumed the opening paren in tokenize
    unless current_token && current_token[:type] == :rparen
      args << parse_expression
      
      while current_token && current_token[:type] == :comma
        consume(:comma)
        args << parse_expression
      end
    end
    
    consume(:rparen)
    
    # Call whitelisted function
    if ALLOWED_FUNCTIONS.key?(func_name)
      begin
        ALLOWED_FUNCTIONS[func_name].call(*args)
      rescue => e
        raise ExpressionError, "Function '#{func_name}' failed: #{e.message}"
      end
    else
      raise ExpressionError, "Unknown function: #{func_name}"
    end
  end
  
  def current_token
    @tokens[@position]
  end
  
  def consume(expected_type)
    token = current_token
    
    if token.nil?
      raise ExpressionError, "Expected #{expected_type} but reached end of expression"
    end
    
    if token[:type] != expected_type
      raise ExpressionError, "Expected #{expected_type} but got #{token[:type]}"
    end
    
    @position += 1
    token
  end
end