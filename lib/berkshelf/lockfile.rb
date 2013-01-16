module Berkshelf
  class Lockfile
    class << self
      # Build a lockfile instance from the local .lock file.
      #
      # @raise [Errno::ENOENT]
      #   when the Lockfile cannot be found
      def load(filename)
        begin
          contents = File.read(filename)
        rescue Errno::ENOENT
          raise ::Berkshelf::LockfileNotFound, "Could not find a valid lock file at #{filename}"
        end

        json = MultiJson.load(contents, symbolize_keys: true)
        sources = json[:sources].map{ |source| ::Berkshelf::CookbookSource.from_json(source) }
        lockfile = new(sources, json[:options])
        lockfile.instance_variable_set(:@sha, json[:sha])
        lockfile
      end
    end

    # @return [Array<Berkshelf::CookbookSource>]
    #   the list of sources for this lockfile
    attr_reader :sources

    # @return [String]
    #   the last known SHA of the Berksfile
    attr_accessor :sha

    # Create a new lockfile instance from the given sources.
    #
    # @param [Array<Berkshelf::CookbookSource>] sources
    #   the list of cookbook sources
    # @param [Hash] options
    #   a list of options to pass to the lockfile
    def initialize(sources = [], options = {})
      @options = options
      @sources = sources
    end

    def save
      File.open(lockfile_name, 'wb') do |file|
        file.write self.to_json + "\n"
      end
    end
    alias_method :write, :save

    # Replace the current list of sources with `sources`. This method does
    # not write out the lockfile - it only changes the state of the object.
    #
    # @param [Array<Berkshelf::CookbookSource>] sources
    #   the list of sources to update
    def update(sources)
      sources = [sources].flatten unless sources.is_a?(Array)

      unless sources.all?{ |cookbook| cookbook.is_a?(::Berkshelf::CookbookSource) }
        raise ::Berkshelf::ArgumentError, "`sources` must be a Berkshelf::CookbookSource!"
      end

      @sources = sources
    end

    # Add the given source to the `sources` list, if it doesn't already exist.
    #
    # @param [Berkshelf::CookbookSource] source
    #   the source to append to the sources list
    def append(source)
      unless source.is_a?(::Berkshelf::CookbookSource)
        raise ::Berkshelf::ArgumentError, "`source` must be a Berkshelf::CookbookSource!"
      end

      @sources.push(source) unless @sources.include?(source)
    end

    # The lockfile name associated with this berksfile
    #
    # @return [String]
    #   the berksfile + '.lock'
    def lockfile_name
      options[:berksfile] + '.lock'
    end

    # Write the current lockfile to a hash
    #
    # @return [Hash]
    #   the hash representation of this lockfile
    #   * :sha [String] the last-known sha for the berksfile
    #   * :sources [Array<Berkshelf::CookbookSource>] the list of sources
    #   * :options [Hash] an arbitrary list of options for this lockfile
    def to_hash
      {
        sha: sha,
        sources: sources,
        options: options
      }
    end

    # The JSON representation of this lockfile
    #
    # Relies on {#to_hash} to generate the json
    #
    # @return [String]
    #   the JSON representation of this lockfile
    def to_json
      MultiJson.dump(self.to_hash, pretty: true)
    end

    private
    # The list of options passed to the lockfile
    #
    # @return [Hash]
    #   the hash of options
    def options
      @options ||= {}
    end
  end
end
