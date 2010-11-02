module ActionController
  module Caching
    module Actions
      def _save_fragment_with_options_processing(name, options)
        depends = options[:depends]
        depends = if depends.is_a?(Symbol)
                    send(depends)
                  elsif depends.respond_to?(:call)
                    instance_exec(self, &depends)
                  else
                    depends
                  end
        _save_fragment_without_options_processing(name, options.merge(:depends => depends))
      end

      alias_method_chain :_save_fragment, :options_processing
    end
  end
end

