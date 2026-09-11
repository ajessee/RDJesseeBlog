# frozen_string_literal: true

module StoriesHelper
  def tag_links(tags)
    tags.split(',').map { |tag| link_to tag.strip, tag_path(tag.strip) }.join(', ')
  end

  def tag_cloud(tags, classes)
    max = tags.max_by(&:count)
    tags.each do |tag|
      index = tag.count.to_f / max.count * (classes.size - 1)
      yield(tag, classes[index.round])
    end
  end

  def autosuggest_aggregate(response, fields, query)
    # Stores unique words and their autocorrect suggestions
    words = {}

    # Iterate over fields
    fields.each do |field|
      # Iterate over query words
      response.send(field).to_a.each do |word|
        # If any options are available
        next if word.options.empty?

        # Append word if it doesn't already exist
        new_word = false
        unless words.include? word.text
          words[word.text] = { text: '', score: nil, freq: nil }
          new_word = true
        end
        word.options.each do |option|
          unless new_word || (words[word.text][:score] * words[word.text][:freq] < option[:score] * option[:freq])
            next
          end

          words[word.text][:text] = option[:text]
          words[word.text][:score] = option[:score]
          words[word.text][:freq] = option[:freq]
        end
      end
    end

    new_query = query.dup

    # Generate a new string based on the high score suggestions
    words.each do |word, suggestion|
      new_query[word] = suggestion[:text] if suggestion[:score] > 0.65
    end

    # Return the new query or false if there were no modifications
    return new_query unless new_query == query

    false
  end

  def pluralize_without_count(count, noun, text = nil)
    if count != 0
      count == 1 ? "#{noun}#{text}" : "#{noun.pluralize}#{text}"
    end
  end

  def get_results(results, story)
    if results
      results = results.select { |r| r.id == story.id.to_s }.first
      title = results.highlight.title.nil? ? story.title : results.highlight.title.first
      content = results.highlight.content.nil? ? story.content : results.highlight.content.join(' / ')
    else
      title = story.title
      content = Truncato.truncate(story.content, max_length: 500) + '(click to continue reading)'
    end
    {
      title: story_html(title),
      content: story_html(content)
    }
  end

  def get_results_query(results)
    results.search.definition[:body][:query][:multi_match][:query]
  end

  def clean_story_params(story_params, params)
    if story_params[:year_written] == 'None'
      params[:story].delete(:year_written)
    end
    params[:story].delete(:decade) if story_params[:decade] == 'None'
    params[:story].delete(:genre) if story_params[:genre] == ''
    params[:story].delete(:location) if story_params[:location] == ''
    params[:story].delete(:category) if story_params[:category] == ''
    params[:story].delete(:life_stage) if story_params[:life_stage] == ''
    unless nested_hash_value(story_params[:recordings_attributes].to_h, :audio_file)
      params[:story].delete(:recordings_attributes)
    end
  end

  def nested_hash_value(obj, key)
    if obj.respond_to?(:key?) && obj.key?(key)
      obj[key]
    elsif obj.respond_to?(:each)
      r = nil
      obj.find { |*a| r = nested_hash_value(a.last, key) }
      r
    end
  end

  def create_sort_link_hash(sort_info_obj, sort_by_string)
    if sort_info_obj.keys.first == sort_by_string.to_sym
      @title = sort_by_string
      @direction = sort_info_obj[sort_by_string.to_sym][:direction]
      @opposite_direction = sort_info_obj[sort_by_string.to_sym][:opposite_direction]
      @icon_class = get_sort_icon_class(@title, @direction)
    else
      @title = sort_by_string
      @direction = 'DESC'
      @opposite_direction = 'ASC'
      @icon_class = get_sort_icon_class(@title, @direction)
    end
    @params = { params: {sort_info: { sort_using: @title, direction: @direction, opposite_direction: @opposite_direction }}, icon_class: @icon_class }
  end

  def get_sort_icon_class(sort_by_string, direction)
    case sort_by_string
    when 'id', 'year_written', 'decade', 'word_count', 'created_at', 'updated_at'
      if direction == 'ASC'
        @icon_class = "fas fa-sort-numeric-down-alt"
      elsif direction == 'DESC'
        @icon_class = "fas fa-sort-numeric-up"
      end
    when 'title', 'location', 'genre', 'category', 'life_stage'
      if direction == 'ASC'
        @icon_class = "fas fa-sort-alpha-down-alt"
      elsif direction == 'DESC'
        @icon_class = "fas fa-sort-alpha-up"
      end
    end
    @icon_class
  end
end
