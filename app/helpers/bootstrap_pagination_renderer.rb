require 'will_paginate/view_helpers/action_view'

# Bootstrap 3 markup using the current will_paginate renderer interface.
class BootstrapPaginationRenderer < WillPaginate::ActionView::LinkRenderer
  protected

  def html_container(html)
    tag(:nav, tag(:ul, html, class: 'pagination'), container_attributes)
  end

  def page_number(page)
    attributes = { 'aria-label': "Page #{page}" }
    attributes['aria-current'] = 'page' if page == current_page
    tag(:li, link(page, page, attributes), class: ('active' if page == current_page))
  end

  def gap
    tag(:li, tag(:span, '&hellip;', 'aria-hidden': 'true'), class: 'disabled')
  end

  def previous_or_next_page(page, text, classname, aria_label = nil)
    content = page ? link(text, page, 'aria-label': aria_label) : tag(:span, text)
    tag(:li, content, class: [classname, ('disabled' unless page)].compact.join(' '))
  end
end
