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

  def get_u1
    get(1).unpack1("C")
  end

  def get_u2
    get(2).unpack1("v")
  end

  def get_u
    get(4).unpack1("V")
  end

  def get_s
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
    when 44
      if @data[16,4] == "root"
        raise "Not supported yet"
      else
        convert_fc_044!
      end
    when 50
      if @data[16,4] == "root"
        raise "Not supported yet"
      else
        convert_fc_050!
      end
    when 51
      if @data[16,4] == "root"
        raise "Not supported yet"
      else
        convert_fc_051!
      end
    when 52
      if @data[16,4] == "root"
        raise "Not supported yet"
      else
        convert_fc_052!
      end
    when 53
      if @data[16,4] == "root"
        raise "Not supported yet"
      else
        convert_fc_053!
      end
    else
      raise "Not supported yet"
    end
  end

  def convert_002!
    out! %Q[<cml version="002">]

    until eof?
      out! "  <key>#{get_s.xml_escape}</key>"
      out! "  <value>#{get_s.xml_escape}</value>"
    end

    out! %Q[</cml>]
  end

  def convert_fc_044!
    out! %Q[<fc version="044">]

    until eof?
      out! "  <fcentry>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <byte>#{get_u1}</byte><!-- B -->"
      out! "    <byte>#{get_u1}</byte><!-- G -->"
      out! "    <byte>#{get_u1}</byte><!-- R -->"
      out! "    <byte>#{get_u1}</byte><!-- A -->"
      out! "  </fcentry>"
    end

    out! %Q[</fc>]
  end

  def convert_fc_050!
    out! %Q[<fc version="050">]

    until eof?
      out! "  <fcentry>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <byte>#{get_u1}</byte><!-- B -->"
      out! "    <byte>#{get_u1}</byte><!-- G -->"
      out! "    <byte>#{get_u1}</byte><!-- R -->"
      out! "    <byte>#{get_u1}</byte><!-- A -->"
      out! "  </fcentry>"
    end

    out! %Q[</fc>]
  end

  def convert_fc_051!
    out! %Q[<fc version="051">]

    until eof?
      out! "  <fcentry>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <byte>#{get_u1}</byte><!-- B -->"
      out! "    <byte>#{get_u1}</byte><!-- G -->"
      out! "    <byte>#{get_u1}</byte><!-- R -->"
      out! "    <byte>#{get_u1}</byte><!-- A -->"
      out! "  </fcentry>"
    end

    out! %Q[</fc>]
  end

  def convert_fc_052!
    out! %Q[<fc version="052">]

    until eof?
      out! "  <fcentry>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <byte>#{get_u1}</byte><!-- B -->"
      out! "    <byte>#{get_u1}</byte><!-- G -->"
      out! "    <byte>#{get_u1}</byte><!-- R -->"
      out! "    <byte>#{get_u1}</byte><!-- A -->"
      out! "    <s>#{get_s.xml_escape}</s><!-- T0 -->"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "  </fcentry>"
    end

    out! %Q[</fc>]
  end

  def convert_fc_053!
    out! %Q[<fc version="053">]

    until eof?
      out! "  <fcentry>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <byte>#{get_u1}</byte><!-- B -->"
      out! "    <byte>#{get_u1}</byte><!-- G -->"
      out! "    <byte>#{get_u1}</byte><!-- R -->"
      out! "    <byte>#{get_u1}</byte><!-- A -->"
      out! "    <s>#{get_s.xml_escape}</s>"
      out! "    <s>#{get_s.xml_escape}</s><!-- T0 -->"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "    <u>#{get_u}</u>"
      out! "  </fcentry>"
    end

    out! %Q[</fc>]
  end

  def out!(s)
    puts s
  end
end
