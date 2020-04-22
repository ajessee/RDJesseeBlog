module StoriesHelper

  def tag_links(tags)
  tags.split(",").map{|tag| link_to tag.strip, tag_path(tag.strip) }.join(", ") 
  end

  def tag_cloud(tags, classes)
    max = tags.sort_by(&:count).last
    tags.each do |tag|
      index = tag.count.to_f / max.count * (classes.size-1)
      yield(tag, classes[index.round])
    end
  end

  def autosuggest_aggregate(response, fields, query)
    # Stores unique words and their autocorrect suggestions
    words = { }
  
    # Iterate over fields
    fields.each do |field|
      # Iterate over query words
      response.send(field).to_a.each do |word|
        # If any options are available
        if word.options.length > 0
          # Append word if it doesn't already exist
          new_word = false
          unless words.include? word.text
            words[word.text] = { text: '', score: nil, freq: nil }
            new_word = true
          end
          word.options.each do |option|
            if new_word or words[word.text][:score] * words[word.text][:freq] < option[:score] * option[:freq]
              words[word.text][:text] = option[:text]
              words[word.text][:score] = option[:score]
              words[word.text][:freq] = option[:freq]
            end
          end
        end
      end
    end
  
    new_query = query.dup
  
    # Generate a new string based on the high score suggestions
    words.each do |word, suggestion|
      if suggestion[:score] > 0.65
        new_query[word] = suggestion[:text]
      end
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
      title = results.highlight.title.nil? ? story.title : results.highlight.title.first.html_safe
      content = results.highlight.content.nil? ? story.content : results.highlight.content.join(' / ').html_safe
    else
      title = story.title.html_safe
      content = Truncato.truncate(story.content, max_length: 500) + '(click to continue reading)'
    end
    {
      title: title,
      content: content.html_safe,
    }
  end

  def get_results_query(results)
    results.search.definition[:body][:query][:multi_match][:query]
  end

  def clean_story_params(story_params, params)
    if story_params[:year_written] == "None"
      params[:story].delete(:year_written)
    end
    if story_params[:decade] == "None"
      params[:story].delete(:decade)
    end
    if story_params[:genre] == ""
      params[:story].delete(:genre)
    end
    if story_params[:location] == ""
      params[:story].delete(:location)
    end
    if story_params[:category] == ""
      params[:story].delete(:category)
    end
    if story_params[:life_stage] == ""
      params[:story].delete(:life_stage)
    end
    if !nested_hash_value(story_params[:recordings_attributes].to_h, :audio_file)
      params[:story].delete(:recordings_attributes)
    end
  end


  def nested_hash_value(obj,key)
    if obj.respond_to?(:key?) && obj.key?(key)
      obj[key]
    elsif obj.respond_to?(:each)
      r = nil
      obj.find{ |*a| r=nested_hash_value(a.last,key) }
      r
    end
  end
  
end
