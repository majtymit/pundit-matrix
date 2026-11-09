module Pundit
  module Matrix
    module GeneratorHelpers
      private

      def steps
        @steps ||= []
      end

      def exist?(path)
        File.exist?(File.join(destination_root, path))
      end

      def read(path)
        File.read(File.join(destination_root, path))
      end

      def inject_after(path, pattern, text, unless_matching: nil)
        return false unless exist?(path)

        content = read(path)
        return false if !content.match?(pattern) || (unless_matching && content.match?(unless_matching))

        inject_into_file(path, text, after: pattern)
        true
      end

      def declare_subject_screen(path)
        return false unless exist?(path)

        content = read(path)
        return true if content.match?(/^\s*subject_screen\b/)
        return replace_screen(path) if content.match?(/^\s*screen :\w+/)

        policy = content.match(/^(\s*)class (?:\w+::)*#{subject_name.demodulize}Policy\b.*\n/)
        return false unless policy

        inject_into_file(path, "#{policy[1]}  subject_screen :#{subject_key}\n\n", after: policy[0])
        true
      end

      def replace_screen(path)
        gsub_file(path, /^(\s*)screen (:\w+)/, '\1subject_screen \2')
        true
      end

      def subject_key
        subject_name.demodulize.underscore.pluralize
      end
    end
  end
end
