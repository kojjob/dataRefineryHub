module IconHelper
  def dataflow_icon(name, options = {})
    classes = [ "dataflow-icon" ]
    classes << options[:class] if options[:class]
    classes = classes.join(" ")

    size = options[:size] || 24

    case name.to_s
    when "logo"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "2", "stroke-linecap": "round", "stroke-linejoin": "round" do
        concat tag(:path, d: "M13 10V3L4 14h7v7l9-11h-7z")
      end
    when "dashboard"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25")
      end
    when "database"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 18.653 16.556 20.5 12 20.5s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125")
      end
    when "analytics"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z")
      end
    when "users"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z")
      end
    when "settings"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z")
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z")
      end
    when "integrations"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244")
      end
    when "pipelines"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M3 7.5L7.5 3m0 0L12 7.5M7.5 3v13.5m13.5 0L16.5 21m0 0L12 16.5m4.5 4.5V7.5")
      end
    when "reports"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z")
      end
    when "billing"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z")
      end
    when "search"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "currentColor" do
        concat tag(:path, "fill-rule": "evenodd", d: "M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z", "clip-rule": "evenodd")
      end
    when "notification"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0")
      end
    when "chevron_down"
      content_tag :svg, class: classes, viewBox: "0 0 20 20", fill: "currentColor" do
        concat tag(:path, "fill-rule": "evenodd", d: "M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z", "clip-rule": "evenodd")
      end
    when "check"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "currentColor" do
        concat tag(:path, d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z")
      end
    when "arrow_right"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "2" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M13 7l5 5m0 0l-5 5m5-5H6")
      end
    when "close"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "2" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M6 18L18 6M6 6l12 12")
      end
    when "menu"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "1.5" do
        concat tag(:path, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5")
      end
    when "play"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "currentColor" do
        concat tag(:path, d: "M8 5v14l11-7z")
      end
    when "star"
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "currentColor" do
        concat tag(:path, d: "M12 2L15.09 8.26L22 9L16 14.74L17.18 21.02L12 18.77L6.82 21.02L8 14.74L2 9L8.91 8.26L12 2Z")
      end
    else
      # Default fallback icon
      content_tag :svg, class: classes, viewBox: "0 0 #{size} #{size}", fill: "none", stroke: "currentColor", "stroke-width": "2" do
        concat tag(:circle, cx: "12", cy: "12", r: "10")
        concat tag(:path, d: "M9,9h6v6h-6z")
      end
    end
  end

  # Integration specific icons
  def integration_icon(name, options = {})
    classes = [ "integration-icon" ]
    classes << options[:class] if options[:class]
    classes = classes.join(" ")

    size = options[:size] || 24

    case name.to_s.downcase
    when "shopify"
      content_tag :div, class: "#{classes} bg-green-600 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "S", class: "font-bold text-xs"
      end
    when "quickbooks"
      content_tag :div, class: "#{classes} bg-blue-600 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "QB", class: "font-bold text-xs"
      end
    when "stripe"
      content_tag :div, class: "#{classes} bg-purple-600 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "S", class: "font-bold text-xs"
      end
    when "google analytics", "google"
      content_tag :div, class: "#{classes} bg-orange-500 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "GA", class: "font-bold text-xs"
      end
    when "mailchimp"
      content_tag :div, class: "#{classes} bg-yellow-500 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "MC", class: "font-bold text-xs"
      end
    when "hubspot"
      content_tag :div, class: "#{classes} bg-orange-600 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "HS", class: "font-bold text-xs"
      end
    when "salesforce"
      content_tag :div, class: "#{classes} bg-blue-500 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "SF", class: "font-bold text-xs"
      end
    when "zendesk"
      content_tag :div, class: "#{classes} bg-green-500 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "ZD", class: "font-bold text-xs"
      end
    when "slack"
      content_tag :div, class: "#{classes} bg-purple-500 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, "SL", class: "font-bold text-xs"
      end
    else
      content_tag :div, class: "#{classes} bg-gray-400 text-white rounded flex items-center justify-center", style: "width: #{size}px; height: #{size}px;" do
        content_tag :span, name.first.upcase, class: "font-bold text-xs"
      end
    end
  end
end
