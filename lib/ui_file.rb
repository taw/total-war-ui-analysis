require "pry"

class String
  # Escape characters for output as XML attribute values (< > & ' ")
  def xml_escape
    replacements = {"<" => "&lt;", ">" => "&gt;", "&" => "&amp;", "\"" => "&quot;", "'" => "&apos;"}
    b.gsub(/([<>&\'\"])/) { replacements[$1] }
  end
end

class UiFile
  def initialize(path, output)
    @path = path
    @data = File.open(path, 'rb').read
    @size = @data.size
    @ofs = 0
    @output = output
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

  def get_bool
    v = get_u1
    raise "Invalid boolean value: #{v}" if v > 1
    v == 1
  end

  def get_u2
    get(2).unpack1("v")
  end

  def get_u
    get(4).unpack1("V")
  end

  def get_i
    get(4).unpack1("i")
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

  def version_string
    "%03d" % @version
  end

  def eof?
    @size == @ofs
  end

  def bytes_left
    @size - @ofs
  end

  # Most UI formats except the latest ones do
  def starts_with_root_ui_entry?
    @data[16,4] == "root"
  end

  def convert_u!(comment=nil)
    if comment
      out! "<u>#{get_u}</u><!-- #{comment} -->"
    else
      out! "<u>#{get_u}</u>"
    end
  end

  def convert_i!(comment=nil)
    if comment
      out! "<i>#{get_i}</i><!-- #{comment} -->"
    else
      out! "<i>#{get_i}</i>"
    end
  end

  def convert_ix!(comment=nil)
    v = get_i
    hex = @data[@ofs-4,4].bytes.map{|x| "%02x" % x }.join(":")
    if comment
      out! "<i>#{v}</i><!-- #{hex} --><!-- #{comment} -->"
    else
      out! "<i>#{v}</i><!-- #{hex} -->"
    end
  end

  def convert_byte!(comment=nil)
    if comment
      out! "<byte>#{get_u1}</byte><!-- #{comment} -->"
    else
      out! "<byte>#{get_u1}</byte>"
    end
  end

  def convert_s!(comment=nil)
    if comment
      out! "<s>#{get_s.xml_escape}</s><!-- #{comment} -->"
    else
      out! "<s>#{get_s.xml_escape}</s>"
    end
  end

  def convert_unicode!(comment=nil)
    if comment
      out! "<unicode>#{get_unicode.xml_escape}</unicode><!-- #{comment} -->"
    else
      out! "<unicode>#{get_unicode.xml_escape}</unicode>"
    end
  end

  def convert_bool!(comment=nil)
    v = get_bool ? "<yes />" : "<no />"
    if comment
      out! "#{v}<!-- #{comment} -->"
    else
      out! v
    end
  end

  def convert_u2!(comment=nil)
    v = get_u2
    if v != 0
      raise "Non zero U2?"
    end
    if comment
      out! "<u2>#{v}</u2><!-- #{comment} -->"
    else
      out! "<u2>#{v}</u2>"
    end
  end

  def convert_image_list!
    count = get_u
    tag! "images", count: count do
      count.times do
        tag! "image" do
          convert_u! "ID"
          convert_s! "path"
          convert_i! "x size"
          convert_i! "y size"
          convert_u! "mask or rgba or something?"
        end
      end
    end
  end

  def convert_state_list!
    out_ofs!
    count = get_u
    tag! "states", count: count do
      count.times do
        tag! "state" do
          convert_u! "ID"
          convert_s! "title - NewState"
          convert_i! "x size"
          convert_i! "y size"

          convert_unicode! "state text"
          convert_unicode! "tooltip"
          5.times do
            convert_i!
          end
          convert_bool!

          convert_unicode! "localization id"
          convert_unicode! "tooltip id"
          convert_s! "font"
          out_ofs! "font done"
          convert_i!
          convert_i!
          convert_u!
          if @version >= 43
            convert_s! "twui"
          end
          convert_i!
          convert_i!
          convert_i!

          convert_bool!
          convert_bool!
          convert_bool!

          if @version >= 29
            convert_s! "T0"
          end

          convert_i!
          convert_i!
          convert_i!
          convert_i!

          out_ofs! "state description start"
          convert_s! "state description"
          convert_s! "event text"
          out_ofs! "image uses start"
          convert_image_uses!

          if @version >= 26 # ???
            convert_i!
            convert_i!
          end
          out_ofs! "transitions start"
          convert_transitions!
        end
      end
    end
  end

  def convert_transitions!
    out_ofs! "transitions"
    count = get_u
    tag! "transitions", count: count do
      count.times do
        tag! "transition" do
          convert_i! "type"
          convert_u! "ID"
          if @version >= 39
            convert_s!
            convert_i!
            convert_i!
          end
          if @version >= 43
            convert_s!
            convert_i!
          end
        end
      end
    end
  end

  def convert_image_uses!
    count = get_u
    tag! "image_uses", count: count do
      count.times do
        tag! "image_use" do
          convert_u! "ID"
          convert_u! "x offset"
          convert_u! "y offset"
          convert_u! "x size"
          convert_u! "y size"
          convert_byte! "B multiply"
          convert_byte! "R multiply"
          convert_byte! "G multiply"
          convert_byte! "A multiply"
          out_ofs!
          convert_bool!
          convert_bool!
          convert_bool!
          convert_i! "position"
          convert_bool!
          convert_bool!
          convert_i!
          convert_i!
          convert_i!
          if @version >= 51
            convert_bool!
          end
          if @version == 31 # WTF ?
            convert_i!
          end
        end
      end
    end
  end

  def convert_uientry!
    tag! "uientry" do
      convert_u! "ID"
      convert_s! "title"
      if @version >= 43
        convert_s! "title2"
      end
      convert_i! "x offset"
      convert_i! "y offset"
      7.times do
        convert_bool!
      end
      if @version >= 47
        convert_bool!
      end
      if @version >= 50
        convert_bool!
        convert_bool!
        convert_bool!
      end
      if @version >= 52
        convert_bool!
      end
      convert_s! "parent name"
      convert_i!
      convert_unicode! "tooltip"
      convert_unicode! "tooltip text"
      convert_i!

      if @version >= 33
        convert_bool!
      end
      if @version >= 39
        convert_i!
      end
      convert_s! "script"
      convert_image_list!
      if @version >= 28
        convert_i!
      end
      if @version >= 32
        convert_i!
      end
      convert_state_list!
      out_ofs! "state list just finished"
      if @version >= 30
        convert_i!
      end
      out_ofs! "do event list now"
      convert_event_list!
      convert_i!

      if @version >= 39
        convert_effects!
      end

      convert_children!

      convert_s! "template"

      if @version >= 44
        out_ofs! "Version 44+ mystery section"
        flag = get_bool
        if flag
          out! "<yes/><!-- optional section -->"
          convert_s! "name"
          count = get_u
          out!("<i>#{count}</i><!-- count data points -->") # generallly 0-5
          count.times do
            convert_i! "data point"
          end
          convert_i! "mystery1"     # generally -2 to 5, but one 130
          convert_i! "mystery2"     # generally 0-2
          convert_bool! "mystery3"  # generally 0 (bool?)
          convert_i! "mystery4"     # generally 1-10
          convert_bool! "mystery5"  # generally 0 or 1 (bool?)
        else
          out! "<no/><!-- optional section -->"
        end
      end

      if @version >= 49
        convert_s!
      end
    end
  end

  def convert_children!
    count = get_u
    tag! "children", count: count do
      count.times do
        convert_uientry!
      end
    end
  end

  def convert_effects!
    count = get_u
    tag! "effects", count: count do
      count.times do
        tag! "effect" do
          convert_s! "name"
          convert_bool!
          convert_bool!
          phases_count = get_u
          tag! "phases", count: phases_count do
            phases_count.times do
              out_ofs! "phase data"
              tag! "phase" do
                11.times do
                  convert_ix!
                end
                if @version >= 50
                  out! "<!-- extra 3 -->"
                  convert_ix!
                  convert_ix!
                  convert_ix!
                end
                v = get_i
                out! "<i>#{v}</i><!-- include optional extra phase details? -->"
                v.times do
                  out_ofs! "optional phase details"
                  convert_ix!
                  convert_s!
                  convert_s!
                end
              end
            end
          end
        end
      end
    end
    out_ofs! "effects end"
  end

  def convert_event_list!
    events = []
    while true
      s = get_s
      break if s == "events_end"
      events << s
    end
    tag! "events" do
      events.each do |ev|
        out! "<event>#{ev.xml_escape}</event>"
      end
    end
  end

  def convert_ui!
    tag! "ui", version: version_string do
      convert_uientry!
      if bytes_left > 0
        out! "<todo>#{bytes_left} bytes</todo>"
        raise "TODO"
      end
    end
  end

  def convert_cml_002!
    tag! "cml", version: version_string do
      until eof?
        out! "<key>#{get_s.xml_escape}</key>"
        out! "<value>#{get_s.xml_escape}</value>"
      end
    end
  end

  def convert_fc!
    tag! "fc", version: version_string do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          if @version >= 50
            convert_u!
            convert_u!
          end
          if @version >= 51
            convert_u!
          end
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
          if @version >= 53
            convert_s!
          end
          if @version >= 52
            convert_s! "T0"
            convert_u!
            convert_u!
            convert_u!
            convert_u!
          end
        end
      end
    end
  end

  def convert!
    @version = get_version

    case @version
    when 2
      convert_cml_002!
    when 44, 50, 51, 52, 53
      if starts_with_root_ui_entry?
        convert_ui!
      else
        convert_fc!
      end
    when 25..54
      convert_ui!
    else
      raise "Not supported yet"
    end
  rescue Exception => err
    out! "<error>"
    out! "  #{err}"
    out! "  Data before fail:"
    ofs = @save_ofs || @ofs
    hex_dump!(ofs-64, ofs)
    out! "  Data from fail #{ofs}:"
    hex_dump!(ofs, ofs+1024)
    out! "</error>"
    raise err
  end

  def out!(*args)
    @output.out!(*args)
  end

  def tag!(*args, &blk)
    @output.tag!(*args, &blk)
  end

  def out_ofs!(comment=nil)
    @save_ofs = @ofs
    if comment
      out! "<!-- #{@ofs} - #{comment} -->"
    else
      out! "<!-- #{@ofs} -->"
    end
  end

  def hex_dump!(s, e)
    s = 0 if s < 0
    @data[s...e].chars.each_slice(16).each do |slice|
      slice = slice.join
      asc = slice.chars.map{|c| c =~ /[\x20-\x7f]/ ? c : "."}.join
      asc += " " * (16 - asc.size)
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      out! "  #{asc} #{hex}\n"
    end
  end
end
