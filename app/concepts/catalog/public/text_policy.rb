# typed: true

module Catalog
  module Public
    class TextPolicy
      extend T::Sig

      sig { params(value: String).returns(T.nilable(String)) }
      def self.violation(value)
        return "semicolon (;)" if value.include?(";")
        return "SQL line comment (--)" if value.include?("--")
        return "SQL block comment opener (/*)" if value.include?("/*")
        return "SQL block comment closer (*/)" if value.include?("*/")
        return "control character" if value.match?(/\p{Cc}/)

        nil
      end
    end
  end
end
