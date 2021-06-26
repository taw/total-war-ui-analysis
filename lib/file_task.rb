require "pathname"

class FileTask
  def initialize(data_path)
    @data_path = Pathname(data_path)
  end

  def version
    unless @version
      unless @data_path.read(10) =~ /\AVersion(\d\d\d)\z/
        raise "No magic header present"
      end
      @version = $1.to_i(10)
    end
    @version
  end

  def fc?
    @data_path.extname == ".fc"
  end

  def cml?
    @data_path.extname == ".cml"
  end

  def ui?
    (not fc?) and (not cml?)
  end

  def full_version
    if cml?
      "cml#{version}"
    elsif fc?
      "fc#{version}"
    else
      "#{version}"
    end
  end

  def game
    @data_path.dirname.basename.to_s
  end

  def basename
    @data_path.basename.to_s
  end

  # These names are a bit dumb tbh

  def converted_root
    Pathname(__dir__).parent + "converted"
  end

  def recreated_root
    Pathname(__dir__).parent + "tmp/recreated"
  end

  def output_root
    Pathname(__dir__).parent + "output"
  end

  def unpacked_root
    Pathname(__dir__).parent + "unpacked"
  end
end
