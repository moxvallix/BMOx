require 'open3'

class BMOx::Llama
  def initialize(template, params = {})
    @prompt = template.read
    params.each do |key, value|
      @prompt.gsub! "<#{key}>", value.to_s
    end
  end

  def generate
    puts @prompt
    raise "Missing llama executable" unless BMOx::LLAMA_CPP.exist?
    output, status = Open3.capture2(
      BMOx::LLAMA_CPP.to_s,
      "-ngl", ENV.fetch("NGL", "24"),
      "-m", BMOx::MODEL.to_s,
      "-p", @prompt,
      "-n", ENV.fetch("N", "768")
    )
    puts status
    output
  end
end