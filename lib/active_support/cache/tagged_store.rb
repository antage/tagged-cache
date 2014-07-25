require "active_support/time"
require "active_support/core_ext/hash/except"

module ActiveSupport
  module Cache
    module TaggedEntry
      attr_accessor :depends
    end

    class TaggedStore < Store
      class Dependencies
        def initialize(initial)
          @tags = initial || []
        end

        def tags
          @tags
        end

        def depends(tag)
          @tags << tag
        end

        def <<(tag)
          @tags << tag
        end

        def concat(*args)
          if args.size == 1 && args.first.is_a?(Array)
            @tags.concat(args.first)
          else
            @tags.concat(args)
          end
        end
      end

      def initialize(options = nil)
        unless options && options[:tag_store] && options[:entity_store]
          raise ":tag_store and :entity_store options are required"
        else
          @tag_store = Cache.lookup_store(*options.delete(:tag_store))
          @entity_store = Cache.lookup_store(*options.delete(:entity_store))

          @options = {}
        end
      end

      def read_tag(key)
        instrument(:read_tag, key) do
          key = expanded_tag(key)
          tag_value = @tag_store.read(key, :raw => true)
          if tag_value.nil? || tag_value.to_i.zero?
            new_value = Time.now.to_i
            @tag_store.write(key, new_value, :raw => true)
            new_value
          else
            tag_value.to_i
          end
        end
      end

      def read_tags(*keys)
        instrument(:read_tags, keys) do
          options = keys.extract_options!
          keys = keys.map { |k| expanded_tag(k) }
          tags = @tag_store.read_multi(*(keys + [options.merge(:raw => true)]))
          (keys - tags.keys).each do |unknown_tag|
            tags[unknown_tag] = read_tag(unknown_tag)
          end
          tags
        end
      end

      def touch_tag(key)
        instrument(:touch_tag, key) do
          key = expanded_tag(key)
          @tag_store.increment(key) || @tag_store.write(key, Time.now.to_i, :raw => true)
        end
      end

      def tagged_fetch(name, options = nil)
        if block_given?
          options = merged_options(options)
          key = namespaced_key(name, options)
          unless options[:force]
            entry = instrument(:read, name, options) do |payload|
              payload[:super_operation] = :fetch if payload
              read_entry(key, options)
            end
          end
          if entry && entry.expired?
            race_ttl = options[:race_condition_ttl].to_f
            if race_ttl and Time.now.to_f - entry.expires_at <= race_ttl
              entry.expires_at = Time.now + race_ttl
              write_entry(key, entry, :expires_in => race_ttl * 2)
            else
              delete_entry(key, options)
            end
            entry = nil
          end

          if entry
            instrument(:fetch_hit, name, options) { |payload| }
            entry.value
          else
            dependencies = Dependencies.new(options[:depends])
            result = instrument(:generate, name, options) do |payload|
              yield(dependencies)
            end
            write(name, result, options.merge(:depends => dependencies.tags))
            result
          end
        else
          read(name, options)
        end
      end

      def delete_matched(matcher, options = nil)
        @entity_store.delete_matched(matcher, options)
      end

      def increment(name, amount = 1, options = nil)
        @entity_store.increment(name, amount, options)
      end

      def decrement(name, amount = 1, options = nil)
        @entity_store.decrement(name, amount, options)
      end

      def cleanup(options = nil)
        @entity_store.cleanup(options)
      end

      def clear(options = nil)
        @entity_store.clear(options)
      end

      protected

      def read_entry(key, options)
        entry = @entity_store.send(:read_entry, key, options)
        if entry.respond_to?(:depends) && entry.depends && !entry.depends.empty?
          tags = read_tags(*entry.depends.keys)
          valid = entry.depends.all? { |k, v| tags[k] == v }
          entry.expires_at = 1.second.ago unless valid
        end
        entry
      end

      def write_entry(key, entry, options)
        depends = (options.delete(:depends) || []).uniq
        unless depends.empty?
          entry.extend(TaggedEntry)
          entry.depends = read_tags(*depends)
        end
        @entity_store.send(:write_entry, key, entry, options)
      end

      def delete_entry(key, options)
        @entity_store.send(:delete_entry, key, options)
      end

      private

      def namespaced_key(key, options)
        key = expanded_key(key)
        namespace = @entity_store.options[:namespace] if @entity_store.options
        prefix = namespace.is_a?(Proc) ? namespace.call : namespace
        key = "#{prefix}:#{key}" if prefix
        key
      end

      def expanded_tag(tag)
        if tag.respond_to?(:cache_tag)
          tag = tag.cache_tag.to_s
        else
          tag.to_s
        end
      end
    end
  end
end
