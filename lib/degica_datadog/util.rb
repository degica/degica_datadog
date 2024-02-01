# frozen_string_literal: true

module DegicaDatadog
  # Utility methods.
  module Util
    class << self
      # Return a path group for a given path.
      def path_group(path)
        return unless path.is_a?(String)
        return "/" if path.empty?

        path
          .split("/")
          .map(&method(:process_path_segment))
          .join("/")
      end

      private

      def process_path_segment(segment)
        return segment if segment =~ /^v\d+$/
        return "?" if segment =~ /\d/

        segment
      end
    end
  end
end
