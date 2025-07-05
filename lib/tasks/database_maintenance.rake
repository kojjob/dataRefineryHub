namespace :db do
  desc "Perform database maintenance (VACUUM, REINDEX, refresh materialized views)"
  task maintenance: :environment do
    puts "🔧 Starting database maintenance..."

    ActiveRecord::Base.connection.execute("SET statement_timeout = 0;")

    # 1. Vacuum and analyze all tables
    puts "  📊 Running VACUUM ANALYZE..."
    begin
      ActiveRecord::Base.connection.execute("VACUUM ANALYZE;")
      puts "  ✅ VACUUM ANALYZE completed"
    rescue => e
      puts "  ❌ VACUUM ANALYZE failed: #{e.message}"
    end

    # 2. Refresh materialized views
    puts "  🔄 Refreshing materialized views..."
    begin
      ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY organization_daily_metrics;")
      puts "  ✅ Materialized views refreshed"
    rescue => e
      puts "  ⚠️  Materialized view refresh failed (may not exist yet): #{e.message}"
    end

    # 3. Update table statistics
    puts "  📈 Updating table statistics..."
    tables = ActiveRecord::Base.connection.tables
    tables.each do |table|
      begin
        ActiveRecord::Base.connection.execute("ANALYZE #{table};")
      rescue => e
        puts "  ⚠️  Failed to analyze #{table}: #{e.message}"
      end
    end
    puts "  ✅ Table statistics updated"

    # 4. Show index usage statistics
    puts "\n📊 Index Usage Statistics:"
    index_stats = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT#{' '}
        schemaname,
        tablename,
        indexname,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        pg_size_pretty(pg_relation_size(indexrelid)) as index_size
      FROM pg_stat_user_indexes
      WHERE schemaname = 'public'
      ORDER BY idx_scan DESC
      LIMIT 20;
    SQL

    puts "  Top 20 Most Used Indexes:"
    puts "  %-30s %-30s %10s %15s %10s" % [ "Table", "Index", "Scans", "Tuples Read", "Size" ]
    puts "  " + "-" * 100
    index_stats.each do |row|
      puts "  %-30s %-30s %10s %15s %10s" % [
        row["tablename"][0..29],
        row["indexname"][0..29],
        row["idx_scan"],
        row["idx_tup_read"],
        row["index_size"]
      ]
    end

    # 5. Find unused indexes
    puts "\n⚠️  Potentially Unused Indexes (0 scans):"
    unused_indexes = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT#{' '}
        schemaname,
        tablename,
        indexname,
        pg_size_pretty(pg_relation_size(indexrelid)) as index_size
      FROM pg_stat_user_indexes
      WHERE schemaname = 'public' AND idx_scan = 0
      ORDER BY pg_relation_size(indexrelid) DESC;
    SQL

    if unused_indexes.any?
      unused_indexes.each do |row|
        puts "  - #{row['tablename']}.#{row['indexname']} (#{row['index_size']})"
      end
    else
      puts "  ✅ No unused indexes found"
    end

    puts "\n✨ Database maintenance completed!"
  end

  desc "Analyze query performance and suggest optimizations"
  task analyze_performance: :environment do
    puts "🔍 Analyzing database performance..."

    # 1. Find slow queries
    puts "\n🐌 Slowest Queries (last 24 hours):"
    slow_queries = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT#{' '}
        query,
        calls,
        mean_time::numeric(10,2) as avg_ms,
        max_time::numeric(10,2) as max_ms,
        total_time::numeric(10,2) as total_ms
      FROM pg_stat_statements
      WHERE query NOT LIKE '%pg_stat_statements%'
        AND calls > 10
      ORDER BY mean_time DESC
      LIMIT 10;
    SQL

    if slow_queries.any?
      slow_queries.each_with_index do |query, i|
        puts "\n#{i + 1}. Average: #{query['avg_ms']}ms, Max: #{query['max_ms']}ms, Calls: #{query['calls']}"
        puts "   Query: #{query['query'][0..200]}..."
      end
    else
      puts "  ℹ️  pg_stat_statements extension may not be enabled"
    end

    # 2. Table bloat analysis
    puts "\n📦 Table Bloat Analysis:"
    bloat_query = <<-SQL
      WITH constants AS (
        SELECT current_setting('block_size')::numeric AS bs, 23 AS hdr, 4 AS ma
      ),
      bloat_info AS (
        SELECT
          schemaname,
          tablename,
          cc.relpages,
          bs,
          CEIL((cc.reltuples*((datahdr+ma-
            (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta
        FROM (
          SELECT
            schemaname,
            tablename,
            hdr,
            ma,
            bs,
            SUM((1-null_frac)*avg_width) AS nullhdr2,
            MAX(hdr) AS datahdr
          FROM pg_stats
          CROSS JOIN constants
          GROUP BY 1,2,3,4,5
        ) AS foo
        JOIN pg_class cc ON cc.relname = tablename
        JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = schemaname
      )
      SELECT
        schemaname,
        tablename,
        pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
        ROUND(100 * (relpages-otta)::numeric/relpages, 1) AS bloat_pct
      FROM bloat_info
      WHERE relpages > 100
        AND (relpages-otta)::numeric/relpages > 0.2
      ORDER BY (relpages-otta)::numeric/relpages DESC
      LIMIT 10;
    SQL

    begin
      bloat_results = ActiveRecord::Base.connection.execute(bloat_query)
      if bloat_results.any?
        bloat_results.each do |row|
          puts "  - #{row['tablename']}: #{row['table_size']} (#{row['bloat_pct']}% bloat)"
        end
      else
        puts "  ✅ No significant table bloat detected"
      end
    rescue => e
      puts "  ⚠️  Could not analyze bloat: #{e.message}"
    end

    puts "\n✨ Performance analysis completed!"
  end

  desc "Run all database optimizations"
  task optimize: [ :maintenance, :analyze_performance ] do
    puts "\n🎉 All database optimizations completed!"
  end
end
