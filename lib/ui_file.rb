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

    # This is for xml output and should probably go to another class
    @stack = []
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

  def convert!
    @version = get_version

    case @version
    when 2
      convert_cml_002!
    when 32
      convert_032!
    when 44
      if starts_with_root_ui_entry?
        raise "Not supported yet"
      else
        convert_fc_044!
      end
    when 50
      if starts_with_root_ui_entry?
        raise "Not supported yet"
      else
        convert_fc_050!
      end
    when 51
      if starts_with_root_ui_entry?
        raise "Not supported yet"
      else
        convert_fc_051!
      end
    when 52
      if starts_with_root_ui_entry?
        raise "Not supported yet"
      else
        convert_fc_052!
      end
    when 53
      if starts_with_root_ui_entry?
        raise "Not supported yet"
      else
        convert_fc_053!
      end
    else
      raise "Not supported yet"
    end
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
      out! "<i>#{get_u}</i><!-- #{comment} -->"
    else
      out! "<i>#{get_u}</i>"
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

  def convert_image_list!
    tag! "images" do
      get_u.times do
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
    tag! "states" do
      get_u.times do
        tag! "state" do
          convert_u! "ID"
          convert_s! "ttile"
          convert_i! "x size"
          convert_i! "y size"

          convert_unicode! "state text"
          convert_unicode! "tooltip"
          5.times do
            convert_i!
          end
          out!(get_bool ? "<yes />" : "<no />")

          out! "<uni>#{get_unicode.xml_escape}</uni><!-- localization id -->"
          out! "<uni>#{get_unicode.xml_escape}</uni><!-- tooltip id -->"
        end
      end
    end
  end

  def convert_uientry_032!
    tag! "uientry" do
      out! "<u>#{get_u}</u><!-- ID -->"
      out! "<s>#{get_s.xml_escape}</s><!-- title -->"
      out! "<i>#{get_i}</i><!-- x offset -->"
      out! "<i>#{get_i}</i><!-- y offset -->"
      7.times do
        out!(get_bool ? "<yes />" : "<no />")
      end
      out! "<s>#{get_s.xml_escape}</s><!-- parent name -->"
      out! "<i>#{get_i}</i>"
      out! "<uni>#{get_unicode.xml_escape}</uni><!-- tooltip -->"
      out! "<uni>#{get_unicode.xml_escape}</uni><!-- tooltip text -->"
      out! "<i>#{get_i}</i>"
      out! "<s>#{get_s.xml_escape}</s><!-- script -->"
      convert_image_list!
      out! "<i>#{get_i}</i>"
      out! "<i>#{get_i}</i>"
      convert_state_list!

      # s
      # int
      # s, s, i, i, f, script, images etc.
    end
  end

  def convert_032!
    tag! "ui", version: "032" do
      convert_uientry_032!
      out! "<todo>#{bytes_left} bytes</todo>"
    end
  end

  def convert_cml_002!
    tag! "cml", version: "002" do
      until eof?
        out! "<key>#{get_s.xml_escape}</key>"
        out! "<value>#{get_s.xml_escape}</value>"
      end
    end
  end

  def convert_fc_044!
    tag! "fc", version: "044" do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
        end
      end
    end
  end

  def convert_fc_050!
    tag! "fc", version: "050" do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
        end
      end
    end
  end

  def convert_fc_051!
    tag! "fc", version: "051" do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
        end
      end
    end
  end

  def convert_fc_052!
    tag! "fc", version: "052" do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
          convert_s! "T0"
          convert_u!
          convert_u!
          convert_u!
          convert_u!
        end
      end
    end
  end

  def convert_fc_053!
    tag! "fc", version: "053" do
      until eof?
        tag! "fcentry" do
          convert_s!
          convert_u!
          convert_s!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_u!
          convert_byte! "B"
          convert_byte! "G"
          convert_byte! "R"
          convert_byte! "A"
          convert_s!
          convert_s! "T0"
          convert_u!
          convert_u!
          convert_u!
          convert_u!
        end
      end
    end
  end

  # XML Builder, maybe more it to another class

  def out!(s)
    puts("  " * @stack.size + s)
  end

  def tag!(name, attrs=nil)
    attrs = attrs_to_s(attrs) if attrs
    if block_given?
      out! "<#{name}#{attrs}>"
      @stack << name
      yield
      @stack.pop
      out! "</#{name}>"
    else
      out! "<#{name}#{attrs}/>"
    end
  end

  def attrs_to_s(attrs={})
    attrs.to_a.map{|k,v| v.nil? ? "" : " #{k}=\"#{v.to_s.xml_escape}\""}.sort.join
  end
end
