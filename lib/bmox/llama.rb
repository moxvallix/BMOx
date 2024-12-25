require 'open3'

class BMOx::Llama
  def self.generate(params = {})
    raise "Missing llama executable" unless BMOx::LLAMA_CPP.exist?
    params.merge! BMOx::CONFIG.fetch(:params, {})
    params = params.transform_keys { |key| "-#{key}" }.flatten(-1).compact
    output, status = Open3.capture2(
      BMOx::LLAMA_CPP.to_s,
      "-m", BMOx::MODEL.to_s,
      *params.map { |value| value.to_s }
    )
    BMOx::PROMPT_LOGGER.add(Logger::INFO, "\n" + output.to_s.strip)

    eot = BMOx::CONFIG.dig(:tokens, :eot) || ""


    return output unless output.include?(eot)
    top, _, bottom = output.rpartition(eot)
    "#{top}#{bottom}"
  end
end