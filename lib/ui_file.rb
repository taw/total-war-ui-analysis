class String
  # Escape characters for output as XML attribute values (< > & ' ")
  def xml_escape
    replacements = {"<" => "&lt;", ">" => "&gt;", "&" => "&amp;", "\"" => "&quot;", "'" => "&apos;"}
    gsub(/([<>&\'\"])/) { replacements[$1] }
  end
end

class UiFile
  def initialize(path)
    @data = File.open(path, 'rb').read
    @size = @data.size
    @ofs = 0
  end

  def get(sz)
    raise "Requested reading past end of file (#{@path}:#{@ofs}) - #{sz}" if @ofs + sz > @data.size
    rv = @data[@ofs, sz]
    @ofs += sz
    rv
  end

  def get_u2
    get(2).unpack1("v")
  end

  def get_u4
    get(4).unpack1("V")
  end

  def get_str
    get(get_u2)
  end

  def get_unicode
    get(get_u2*2).unpack("v*").pack("U*")
  end

  def get_version
    raise "Trying to get Version block at wrong offset" unless @ofs == 0
    raise "Not UI file" unless get(7) == "Version"
    v = get(3)
    raise "Not UI file" unless v =~ /[0-9]{3}/
    v.to_i
  end

  def eof?
    @size == @ofs
  end

  def supported?
    @version == 2
  end

  def convert!
    @version = get_version

    case @version
    when 2
      convert_002!
    else
      raise "Not supported yet"
    end
  end

  def convert_002!
    out! %Q[<cml version="002">]

    until eof?
      k = get_str
      v = get_str
      out! "  <key>#{k.xml_escape}</key>"
      out! "  <value>#{k.xml_escape}</value>"
    end

    out! %Q[</cml>]
  end

  def out!(s)
    puts s
  end
end
