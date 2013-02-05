# encoding: utf-8

module CarrierWave

  module Uploader
    module FogCache
      extend ActiveSupport::Concern
      include CarrierWave::Uploader::Cache

      module ClassMethods

        def clean_cached_files!(seconds=60*60*24)
          super

=begin
          #Here's the super class implementation for reference:
          Dir.glob(File.expand_path(File.join(cache_dir, '*'), CarrierWave.root)).each do |dir|
            time = dir.scan(/(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/).first.map { |t| t.to_i }
            time = Time.utc(*time)
            if time < (Time.now.utc - seconds)
              FileUtils.rm_rf(dir)
            end
          end
=end

          access_fog_cache do |fog|
            fog.directory.files.each do |file|
              time = file.key.split("/").last.scan(/(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})/).first.map { |t| t.to_i }
              file.delete if Time.utc(*time) < (Time.now.utc - seconds)
            end
          end

        end

        def cache!(new_file = sanitized_file)
          super
          access_fog_cache do |fog|
            #TODO: Do we need to worry about it being sanitized?
            fog.store(new_file)
          end
        end

        def retrieve_from_cache!(cache_name)
#          TODO: I'm afraid that if in heroku you get a subsequent request to handle previewing an unsaved model and it hits the original dyno the
#                this might cause us to use the locally cached files url (that is only available on that one dyno and for undetermined length of
#                time). I've lefet these here because it may prove out to be unfeasible to have no access at all on the locally cached version.
#          if cache_path.present?
#            super
#          else #We presume the local cache is not available and the file is only accessible through Fog
            access_fog_cache do |fog|
              fog.retrieve!(cache_name) #We should use cache_name as the identifier, but how do we ensure this?
            end
#          end
        end

        private
        def access_fog_cache
          orig_fog_dir = fog_directory
          fog_directory = cache_dir
          begin
            fog = CarrierWave::Storage::Fog.new(self)
            #TODO: This directory might not exists if this is the first time accessing it. In that case we should create it.
            #fog.create_the_dir_or_smthn unless fog.the_dir.exists?
            yield fog
          ensure
            fog_directory = orig_fog_dir
          end
        end

      end

    end
  end

end