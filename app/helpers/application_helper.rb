module ApplicationHelper
  def story_html(html)
    sanitize(html, tags: Rails::HTML5::SafeListSanitizer.allowed_tags.to_a | ['mark'])
  end

  def will_paginate(collection = nil, options = {})
    super(collection, options.reverse_merge(renderer: BootstrapPaginationRenderer))
  end


  include StoriesHelper
  
  def full_title(page_title)
    base_title = "RDJ Blog"
    if page_title.empty?
      base_title
    else
      "#{base_title} | #{page_title}"
    end
  end

  def ga_script
    tracking_id = "UA-98485844-1"
    if Rails.env.production?
      javascript_tag("(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)})(window,document,'script','//www.google-analytics.com/analytics.js','ga');ga('create', '#{tracking_id}', 'auto');")
    end
  end

  def ga_track
    javascript_tag("if(window.ga != undefined){ga('send', 'pageview');}")
  end
end
