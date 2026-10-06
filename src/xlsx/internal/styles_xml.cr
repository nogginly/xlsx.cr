require "./internal"

module XLSX
  module Internal
    # Reads `xl/styles.xml` to tell which cell styles (`cellXfs` indices, the
    # `s` attribute of a `<c>`) display a date or time, and converts between
    # `Time` and Excel's serial numbers.
    #
    # A date is stored as a plain number, a count of days, so its style's number
    # format is the only thing that marks it as a date. Built-in formats that do
    # (ECMA-376 Part 1, 18.8.30):
    #
    # - 14-17: date (short date, d-mmm-yy, d-mmm, mmm-yy)
    # - 18-21: time (h:mm AM/PM, h:mm:ss AM/PM, h:mm, h:mm:ss)
    # - 22: date and time (m/d/yy h:mm)
    # - 45-47: time (mm:ss, [h]:mm:ss, mm:ss.0)
    #
    # The locale-specific built-ins (27-36, 50-58) are not recognised. Custom
    # formats (ID 164 and up) are recognised by the characters in their code.
    class StylesXML
      NS_MAP = {"ns" => MAIN_NS}

      # Indices of the date-only, time-only and date-time styles in the
      # stylesheet `Zip` writes for a new workbook, used by `DateValue`'s
      # factories. In a template's stylesheet they may name other styles.
      DEFAULT_DATE_STYLE      = 1
      DEFAULT_TIME_STYLE      = 2
      DEFAULT_DATE_TIME_STYLE = 3

      # Built-in format IDs that display a date, a time or both.
      BUILTIN_DATE_FORMAT_IDS = Set{14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47}

      # Characters in a format code that indicate a date/time format.
      DATE_FORMAT_CHARS = {'y', 'm', 'd', 'h', 's'}

      # Whether serial numbers count from 1904 (legacy Mac workbooks) rather
      # than 1900. `Zip` never sets it, so every workbook is read and written
      # in the 1900 system.
      getter date1904 : Bool

      def initialize(@date1904 : Bool = false)
        @date_xf_indices = Set(Int32).new
        @custom_formats = {} of Int32 => String # numFmtId → formatCode
      end

      # Whether the style at *xf_index* displays a date or time.
      def date_format?(xf_index : Int32) : Bool
        @date_xf_indices.includes?(xf_index)
      end

      # Reads the date and time styles from a `styles.xml` document.
      def parse(xml : String) : Nil
        doc = XML.parse(xml)

        # Custom formats first, since checking an xf looks its format up.
        doc.xpath_nodes("//ns:styleSheet/ns:numFmts/ns:numFmt", NS_MAP).each do |node|
          id = node["numFmtId"]?.try(&.to_i)
          code = node["formatCode"]?
          next unless id && code
          @custom_formats[id] = code
        end

        # Inspect each xf in cellXfs to see if it references a date format.
        doc.xpath_nodes("//ns:styleSheet/ns:cellXfs/ns:xf", NS_MAP).each_with_index do |node, i|
          num_fmt_id = node["numFmtId"]?.try(&.to_i) || 0
          @date_xf_indices << i if date_format_id?(num_fmt_id)
        end
      end

      # Converts a serial number to a UTC `Time`, rounded to the second. In the
      # 1900 system, serials before 61 (1 March 1900) come out a day early,
      # because Excel counts a 29 February 1900 that never existed.
      def serial_to_time(serial : Float64) : Time
        epoch = date1904 ? Time.utc(1904, 1, 1) : Time.utc(1899, 12, 30)
        days = serial.to_i
        frac = serial - days
        secs = (frac * 86400).round.to_i
        epoch + days.days + secs.seconds
      end

      # Converts *time* to a serial number from its wall-clock fields, ignoring
      # its offset and anything finer than a second.
      def time_to_serial(time : Time) : Float64
        epoch = date1904 ? Time.utc(1904, 1, 1) : Time.utc(1899, 12, 30)
        wall = Time.utc(time.year, time.month, time.day,
          time.hour, time.minute, time.second)
        diff = wall - epoch
        diff.total_days
      end

      private def date_format_id?(num_fmt_id : Int32) : Bool
        return true if BUILTIN_DATE_FORMAT_IDS.includes?(num_fmt_id)
        return false if num_fmt_id < 164 # other built-ins are not dates
        code = @custom_formats[num_fmt_id]?
        return false unless code
        date_format_code?(code)
      end

      # Whether *code* contains a date or time character outside double quotes.
      # Bracketed sections are not skipped, so `[Red]0.00` counts as a date.
      private def date_format_code?(code : String) : Bool
        in_quote = false
        code.each_char do |ch|
          if ch == '"'
            in_quote = !in_quote
          elsif !in_quote && DATE_FORMAT_CHARS.includes?(ch.downcase)
            return true
          end
        end
        false
      end
    end
  end
end
