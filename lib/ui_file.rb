require "pry"

class Float
  def pretty_single
    rv = (((100_000.0 * self).round / 100_000.0) rescue self)
    return rv if [self].pack("f") == [rv].pack("f")
    self
  end
end

class String
  # Escape characters for output as XML attribute values (< > & ' ")
  def xml_escape
    replacements = {"<" => "&lt;", ">" => "&gt;", "&" => "&amp;", "\"" => "&quot;", "'" => "&apos;", "\r" => "&#xD;"}
    b.gsub(/([<>&\'\"\r])/) { replacements[$1] }
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

  def get_flt
    get(4).unpack1("f").pretty_single
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

  def convert_id!
    v4 = @data[@ofs,4].unpack("C*").map{|x| "%02x" % x}.join(" ")
    v = get_u
    out! "<u>#{v}</u><!-- ID (#{v4}) -->"
  end

  def convert_i!(comment=nil)
    if comment
      out! "<i>#{get_i}</i><!-- #{comment} -->"
    else
      out! "<i>#{get_i}</i>"
    end
  end

  def convert_i_zero!(comment=nil)
    # Well, at least it looks like it
    v = get_i
    if comment
      raise "Must be zero, got #{v} / #{@data[@ofs-4,4].unpack1("f")} (#{comment})" unless v == 0
      out! "<i>#{v}</i><!-- always zero --><!-- #{comment} -->"
    else
      raise "Must be zero, got #{v} / #{@data[@ofs-4,4].unpack1("f")}" unless v == 0
      out! "<i>#{v}</i><!-- always zero -->"
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

  def convert_flt!(comment=nil)
    i = @data[@ofs,4].unpack1("V")
    if comment
      out! "<flt>#{get_flt}</flt><!-- (#{i}) --><!-- #{comment} -->"
    else
      out! "<flt>#{get_flt}</flt><!-- (#{i}) -->"
    end
  end

  def convert_angle!(comment=nil)
    i = @data[@ofs,4].unpack1("V")
    v = get_flt
    vdeg = (v * 180.0 / Math::PI).round(2)
    if comment
      out! "<flt>#{v}</flt><!-- (#{i}) / (#{vdeg} degrees) --><!-- #{comment} -->"
    else
      out! "<flt>#{v}</flt><!-- (#{i}) / (#{vdeg} degrees) -->"
    end
  end

  def convert_bgra!(comment=nil)
    if comment
      out! "<!-- #{comment} -->"
    end
    tag! "color" do
      convert_byte! "B"
      convert_byte! "G"
      convert_byte! "R"
      convert_byte! "A"
    end
  end

  def convert_image_list!
    count = get_u
    tag! "images", count: count do
      count.times do
        tag! "image" do
          convert_id!
          convert_s! "path"
          convert_i! "x size"
          convert_i! "y size"
          if @version < 74
            convert_bgra!
          end
          if @version >= 78
            convert_bool!
          end
        end
      end
    end
  end

  def convert_debug!(size)
    v = get(size).chars
    out! %Q[<debug size="#{size}">]
    v.each_slice(16) do |slice|
      slice = slice.join
      asc = slice.chars.map{|c| c =~ /[\x20-\x7e]/ ? c : "."}.join
      asc += " " * (16 - asc.size)
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      out! "  #{asc} #{hex}\n"
    end
    out! "</debug>"
  end

  def convert_data!(size)
    v = get(size).bytes
    out! %Q[<data size="#{size}">]
    v.each_slice(16) do |slice|
      hex = slice.map{|c| "%02x" % c}.join(" ")
      out! "  #{hex}\n"
    end
    out! "</data>"
  end

  def convert_data_zero!(size)
    v = get(size).bytes
    out! %Q[<data size="#{size}">]
    v.each_slice(16) do |slice|
      hex = slice.map{|c| "%02x" % c}.join(" ")
      out! "  #{hex}\n"
      raise "Data should be all zeroes, got: #{v}" unless slice.all?(&:zero?)
    end
    out! "</data>"
  end

  def convert_state_list!
    out_ofs!
    count = get_u
    tag! "states", count: count do
      count.times do
        tag! "state" do
          convert_id!
          convert_s! "title - NewState"
          convert_i! "x size"
          convert_i! "y size"

          convert_unicode! "state text"
          convert_unicode! "tooltip"
          convert_i! "text xsize?"
          convert_i! "text ysize?"
          convert_i! "text xalign?"
          convert_i! "text yalign?"
          convert_i!
          convert_bool!

          convert_unicode! "localization id"
          convert_unicode! "tooltip id"

          if @version >= 29
            convert_s! "font"
            out_ofs! "font done"
            convert_i! "font size? line height?"
            convert_i! "font leading?"
            convert_i! "font tracking?"
          end

          if @version >= 74
            convert_bgra!
          end
          if @version >= 43
            convert_s! "font category / twui"
          end
          if @version >= 86
            convert_i! "left ?"
            convert_i! "right ?"
            convert_i! "top ?"
            convert_i! "bottom ?"
          else
            convert_i! "x ?"
            convert_i! "y ?"
          end

          if @version >= 83
            convert_i!
            convert_bool!
            convert_bool!
            convert_bool!
            convert_bool!
          else
            convert_i!
            convert_bool!
            convert_bool!
            convert_bool!
          end

          if @version >= 29
            convert_s! "shader name"
            convert_flt! "shader vars"
            convert_flt! "shader vars"
            convert_flt! "shader vars"
            convert_flt! "shader vars"
          end

          if @version >= 77
            convert_s! "text shader name"
            convert_flt! "text shader vars"
            convert_flt! "text shader vars"
            convert_flt! "text shader vars"
            convert_flt! "text shader vars"
          end

          out_ofs! "shaders done"

          if @version < 74
            convert_s! "state description"
            convert_s! "event text"
          end

          # 74 and 77 OK up to this point
          out_ofs! "image use list"

          convert_image_uses!

          if @version >= 26 # something mouse related???
            convert_i!
            convert_i!
          end

          if @version < 74
            convert_transitions!
          else
            convert_mouse_states!
          end
        end
      end
    end
  end

  def convert_mouse_state_data!
    count = get_u
    tag! "mouse_state_data", count: count do
      count.times do
        tag! "mouse_state_datapoint" do
          convert_id!
          convert_s!
          convert_i_zero! # is it two string actually?
        end
      end
    end
  end

  def convert_mouse_states!
    count = get_u
    tag! "mouse_states", count: count do
      count.times do
        tag! "mouse_state" do
          convert_i! "type"
          convert_id!
          convert_i!
          convert_i!
          out_ofs! "mouse nested stuff starts"
          convert_mouse_state_data!
        end
      end
    end
  end

  def convert_transitions!
    count = get_u
    tag! "transitions", count: count do
      count.times do
        tag! "transition" do
          convert_i! "type"
          convert_id!
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
          convert_id!
          convert_u! "x offset"
          convert_u! "y offset"
          convert_u! "x size"
          convert_u! "y size"
          convert_bgra! "multiply"
          # Up to this point, this works for 74+ too
          out_ofs! "less decoded part of image_use follows"
          convert_bool! "tiled?"
          convert_bool! "flipped x?"
          convert_bool! "flipped y?"
          convert_i! "dock position (0-9)?"
          if @version >= 77 # or sth
            convert_i! "dock offset x?"
            convert_i! "dock offset y?"
          end
          convert_bool! "stretch x?"
          convert_bool! "stretch y?"
          convert_angle! "rotation angle"
          convert_flt! "rotation pivot x?"
          convert_flt! "rotation pivot y?"
          if @version >= 74
            convert_s! "shader name"
            convert_flt! "rotation axis x?"
            convert_flt! "rotation axis y?"
            convert_flt! "rotation axis z?"
            convert_i_zero!

            # There is extra shit here :-(
            out_ofs! "extra stuff?"
            if @version <= 77
              convert_bool! "extra image use stuff?"
            end
            convert_i! "extra bg use stuff?"
            convert_i! "extra bg use stuff?"
          else
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
  end

  def convert_anim_attrs!
    count = get_u
    tag! "anim_attrs", count: count do
      count.times do
        tag! "anim_attr" do
          out_ofs! "anim attr start"
          convert_id!
          convert_s! "animation?"
          convert_s! "state?"
          convert_s! "property?"
          out_ofs! "anim attr done"
        end
      end
    end
  end

  def convert_anims!
    count = get_u
    tag! "anims", count: count do
      count.times do
        tag! "anim" do
          out_ofs! "start of anim"
          # v110+ stuff
          convert_flt! "x offset?"
          convert_flt! "y offset?"
          convert_i! "x size?"
          convert_i! "y size?"
          convert_bgra!
          convert_flt! "shader vars?"
          convert_flt! "shader vars?"
          convert_flt! "shader vars?"
          convert_flt! "shader vars?"
          convert_flt! "rotation angle?"
          convert_i! "image index 1?"
          convert_i! "image index 2?"
          # v110+ stuff
          convert_i! "interpolation time?"
          convert_i! "interpolation property mask?"
          convert_flt! "easing weight?"
          convert_s! "easing curve?"
          convert_anim_attrs!
          # v90+ shuff
          out_ofs! "end of anim"
        end
      end
    end
  end

  def convert_funcs!
    count = get_u
    tag! "funcs", count: count do
      count.times do
        tag! "func" do
          convert_s! "name"
          convert_bool! "propagate?"
          convert_bool! "makenoninteractive?"
          convert_anims!
          out_ofs! "end of func"
          # v91+ has extra stuff
        end
      end
    end
  end

  def convert_dynamics!
    count = get_u
    tag! "dynamics", count: count do
      count.times do
        tag! "dynamic" do
          convert_s! "key"
          convert_s! "value"
        end
      end
    end
  end

  def convert_uientry_gen2!
    tag! "uientry" do
      convert_id!
      convert_s! "title"
      if @version >= 43
        convert_s! "title2"
      end

      # version 100+ has some event stuff here

      convert_i! "x offset"
      convert_i! "y offset"

      12.times do |i|
        convert_bool!
      end
      convert_bool! if @version < 90

      convert_unicode! "tooltip text"
      convert_unicode! "tooltip id"

      convert_ix! "docking?"
      if @version >= 77
        convert_ix! "docking x?"
        convert_ix! "docking y?"
      end

      convert_bool!
      convert_i! "default state id"

      convert_image_list!

      convert_ix! "mask image?"

      if @version < 110
        convert_i!
      end

      convert_state_list!

      convert_dynamics!
      convert_i! "priority?"
      out_ofs! "before number of funcs?"
      convert_funcs!

      out_ofs! "children start here?"

      convert_children!

      out_ofs! "children end here?"

      convert_additional_data!

      out_ofs! "additional data ends here?"

      # This version mix...
      if @version <= 84 and @version != 77 and @version != 78
        convert_s! "end of uientry 1?"
        convert_data! 5 # if it's not all zeroes, we could have VariantMeshDefinition stuff following :-/
      else
        convert_s! "end of uientry 1?"
        convert_s! "end of uientry 2?"
        convert_data! 4
      end
    end
  end

  def convert_uientry!
    tag! "uientry" do
      convert_id!
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
      convert_unicode! "tooltip text"
      convert_unicode! "tooltip id"
      convert_i!

      if @version >= 33
        convert_bool!
      end
      if @version >= 39
        convert_i! "default state id"
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
      if @version >= 29
        convert_i!
      end

      # in versions 29 and 30 there's sometimes a lone byte but at root level only here for some reason???
      # is the parser searching for "events_end" and that's why it can ignore some small amount of crap?
      # doesn't sound very likely, but I can't see any other logic to it

      out_ofs! "do event list now"
      convert_event_list!
      convert_i!

      if @version >= 39
        convert_effects!
      end

      convert_children!

      convert_s! "template"

      if @version >= 44
        convert_additional_data!
      end

      if @version >= 49
        convert_s!
      end
    end
  end

  def convert_additional_data!
    out_ofs! "additional data section"
    flag = get_bool
    if flag
      type = get_s
      tag! "additional_data", type: type do
        if type == "List" or type == "HorizontalList"
          count = get_u
          out!("<i>#{count}</i><!-- count data points -->") # generallly 0-5
          count.times do
            convert_flt! "data point"
          end
          convert_i! "mystery1"     # generally -2 to 5, but one 130
          convert_i! "mystery2"     # generally 0-2
          convert_bool! "mystery3"
          convert_i! "mystery4"     # generally 1-10
          if @version >= 54
            convert_bool! "mystery5"
          end
        elsif type == "Table"
          row_count = get_u
          tag! "table", count: row_count do
            row_count.times do
              col_count = get_u
              tag! "row", count: col_count do
                col_count.times do
                  tag! "col" do
                    5.times do
                      convert_flt! "data point"
                    end
                  end
                end
              end
            end
          end
          out_ofs! "end of table data"
        else
          raise "Unknown additional data section #{type}"
        end
      end
    else
      tag! "additional_data", type: "none"
    end
  end

  def convert_children!
    count = get_u
    tag! "children", count: count do
      count.times do
        if @version <= 54
          convert_uientry!
        else
          convert_uientry_gen2!
        end
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
      if @version <= 54
        convert_uientry!
      else
        convert_uientry_gen2!
      end
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
    when 25..999
      convert_ui!
    else
      raise "Not supported yet"
    end
  rescue Exception => err
    tag! "error", msg: err do
      out! "Data before fail:"
      ofs = @save_ofs || @ofs
      hex_dump!(ofs-64, ofs)
      out! "Data from fail #{ofs}:"
      hex_dump!(ofs, ofs+1024)
    end
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
      asc = slice.chars.map{|c| c =~ /[\x20-\x7e]/ ? c : "."}.join
      asc += " " * (16 - asc.size)
      hex = slice.bytes.map{|c| "%02x" % c}.join(" ")
      out! "#{asc} #{hex}\n"
    end
  end
end
