require "./internal"

module XLSX
  module Internal
    # Parses `xl/styles.xml` to identify which cell format (`xf`) indices
    # represent date-formatted cells.
    #
    # Excel stores dates as floating-point serial numbers. The only way to
    # distinguish a date cell from a plain number is the `numFmtId` referenced
    # by the cell's style index (`s` attribute on `<c>`).
    #
    # Built-in date format IDs (ECMA-376 §18.8.30):
    #   14–17: date only  (m/d/yy, d-mmm-yy, d-mmm, mmm-yy)
    #   18–19: time only  (h:mm AM/PM, h:mm:ss AM/PM)
    #   20–21: time       (h:mm, h:mm:ss)
    #   22:    date+time  (m/d/yy h:mm)
    #   45–47: time       (mm:ss, [h]:mm:ss, mm:ss.0)
    #
    # Custom formats (numFmtId >= 164) are detected by inspecting their
    # formatCode for date/time pattern characters.
    class StylesXML
      NS_MAP = {"ns" => MAIN_NS}

      # Built-in numFmtId values used by default DateValue factory methods.
      # These correspond to the first xf index in minimal_styles that uses
      # each format — index 1 for date-only, 2 for time-only, 3 for date+time.
      DEFAULT_DATE_STYLE      = 1
      DEFAULT_TIME_STYLE      = 2
      DEFAULT_DATE_TIME_STYLE = 3

      # Date-only and date+time built-in format IDs.
      BUILTIN_DATE_FORMAT_IDS = Set{14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47}

      # Characters in a format code that indicate a date/time format.
      DATE_FORMAT_CHARS = {'y', 'm', 'd', 'h', 's'}

      # Whether the workbook uses the 1904 date system (legacy Mac).
      # Affects the epoch used for serial number conversion.
      getter date1904 : Bool

      def initialize(@date1904 : Bool = false)
        @date_xf_indices = Set(Int32).new
        @custom_formats = {} of Int32 => String # numFmtId → formatCode
      end

      # Returns true if *xf_index* (the `s` attribute on a `<c>` element)
      # refers to a date-formatted cell format.
      def date_format?(xf_index : Int32) : Bool
        @date_xf_indices.includes?(xf_index)
      end

      # Parses `xl/styles.xml`.
      def parse(xml : String) : Nil
        doc = XML.parse(xml)

        # Collect custom number formats first.
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

      # -----------------------------------------------------------------------
      # Serial number ↔ Time conversion (wall-clock UTC semantics)
      # -----------------------------------------------------------------------

      # Converts an Excel serial number to a `Time` (UTC, wall-clock).
      def serial_to_time(serial : Float64) : Time
        epoch = date1904 ? Time.utc(1904, 1, 1) : Time.utc(1899, 12, 30)
        days = serial.to_i
        frac = serial - days
        secs = (frac * 86400).round.to_i
        epoch + days.days + secs.seconds
      end

      # Converts a `Time` to an Excel serial number (wall-clock, ignores offset).
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

      # Heuristic: a format code is a date if it contains date/time pattern
      # characters outside of quoted sections.
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
