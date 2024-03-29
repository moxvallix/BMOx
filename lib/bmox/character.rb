class BMOx::Character
  CONFIG = {
    "avatar" => "https://cdn.discordapp.com/avatars/1107979697700229142/08fc3e87798ef809b29e0ca3458bf0ae.webp",
    "name" => "Assistant",
    "prompt_id" => nil,
    "reverse_prompt" => "### <username>:"
  }

  CONFIG.each do |key, _|
    define_method(:"#{key}") { self.instance_variable_get("@#{key}") }
  end

  def initialize(contents, substitutes = {})
    @raw = contents
    @config = YAML.parse(contents).to_ruby
    @prompt = contents.gsub(/(---|)[\s\S]+---/, "").strip
    @initial_substitutes = substitutes

    CONFIG.each do |key, value|
      self.instance_variable_set("@#{key}", @config.fetch(key, value))
    end
  end

  def discord_author
    Discordrb::Webhooks::EmbedAuthor.new(name: @name, icon_url: @avatar)
  end

  def substitute_string(string, additional_substitutes = {})
    format_string(string, @initial_substitutes.merge(additional_substitutes))
  end

  def reply_to(message, substitutes = {}, params = {}, bindings = {})
    subs = combine_hashes(@initial_substitutes, substitutes, evaluate_variables(bindings))
    prompt = format_string(@prompt, subs.merge({prompt: message}))
    r_prompt = format_string(@reverse_prompt, subs)
    params.merge!({"p": prompt, "r": r_prompt})
    puts @config
    puts params
    # params.merge!({"-prompt-cache": prompt_cache_file, "-prompt-cache-all": nil, "-file": prompt_history_file})
    output = BMOx::Llama.generate(params)
    output.sub(prompt, "").strip
  end

  private

  def combine_hashes(target = {}, *targets)
    return {} unless target.is_a?(Hash)
    targets.each { |hash| next unless hash.is_a?(Hash); target = target.merge(hash) }
    target
  end

  def format_string(string, variables)
    variables.each { |key, value| string = string.to_s.gsub("<#{key}>", value.to_s) }
    string
  end

  def variables_bind(bindings = {})
    OpenStruct.new({config: @config}.merge(bindings))
  end

  def evaluate_variables(bindings = {})
    bind = variables_bind(bindings)
    output = {}
    BMOx::CONFIG.fetch(:variables, {}).each do |variable, code|
      begin
        evaluated = bind.instance_eval(code).to_s
      rescue => e
        evaluated = ""
        BMOx::LOGGER.error(Logger::ERROR, "Failed to evaluate variable... #{e.message}")
      end
      output[variable] = evaluated
    end
    output
  end

  def check_prompt_id
    raise "Character missing a prompt id" unless @prompt_id.is_a? String
    raise "Prompt id contains invalid characters" if @prompt_id.match? /[^a-z0-9_\-]/
  end

  def prompt_cache_file
    check_prompt_id
    BMOx::MEMORY_DIR.join("#{@prompt_id}.prompt-cache")
  end

  def prompt_history_file
    check_prompt_id
    BMOx::MEMORY_DIR.join("#{@prompt_id}.prompt-history")
  end
end