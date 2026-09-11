module EditorHelper
  # These fields store HTML in ordinary columns, not Action Text records.
  def plain_html_editor(form, attribute, options = {})
    input_id = form.field_id(attribute, :input)
    safe_join([
      form.hidden_field(attribute, id: input_id),
      content_tag('trix-editor', '', options.merge(input: input_id))
    ])
  end
end
