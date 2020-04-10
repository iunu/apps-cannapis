# frozen_string_literal: true

require_relative './common'
require 'fileutils'
require 'pmap'

namespace :artemis do
  namespace :data do
    desc 'Download a batch and relevant associated records for testing. Required params: ARTEMIS_ID, FACILITY_ID, BATCH_ID'
    task :sync do
      helper = BatchFetchHelper.new
      helper.dump
    end

    class BatchFetchHelper
      def initialize
        @artemis_id = ENV['ARTEMIS_ID']
        @facility_id = ENV['FACILITY_ID']
        @batch_id = ENV['BATCH_ID']
        
        validate!
      end

      def dump
        write_data("facilities/#{@facility_id}.json", prettify(facility.body))
        write_data("facilities/#{@facility_id}/resource_units.json", prettify(resource_units.body))
        resource_unit_ids.peach(10) do |id|
          write_data("facilities/#{@facility_id}/resource_units/#{id}.json", prettify(resource_unit(id).body))
        end
        write_data("facilities/#{@facility_id}/batches/#{@batch_id}.json", prettify(batch.body))
        write_data("facilities/#{@facility_id}/batches/#{@batch_id}/completions.json", prettify(completions.body))
        write_data("facilities/#{@facility_id}/batches/#{@batch_id}/items.json", prettify(items.body))
      end

      private

      def prettify(json_str)
        JSON.pretty_generate(JSON.parse(json_str))
      end

      def path
        Rails.root.join('spec/support/data/api/sync')
      end

      def write_data(filename, data)
        output_path = path.join(filename)
        FileUtils.mkdir_p(File.dirname(output_path))

        puts "Writing to #{output_path}..."
        File.open(output_path, 'w') { |f| f.write(data) }
      end

      def facility
        client.oauth_token.get("/api/v3/facilities/#{@facility_id}")
      end

      def resource_units
        @resource_units ||= client.oauth_token.get("/api/v3/facilities/#{@facility_id}/resource_units")
      end

      def resource_unit(id)
        client.oauth_token.get("/api/v3/facilities/#{@facility_id}/resource_units/#{id}")
      end

      def resource_unit_ids
        JSON.parse(resource_units.body)['data'].map { |r| r['id'] }
      end

      def batch
        client.oauth_token.get("/api/v3/facilities/#{@facility_id}/batches/#{@batch_id}?include=zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone")
      end
      
      def items
        batch_data = JSON.parse(batch.body)
        seeding_unit_id = batch_data.dig('data', 'relationships', 'seeding_unit', 'data', 'id')

        client.oauth_token.get("/api/v3/facilities/#{@facility_id}/batches/#{@batch_id}/items?filter[seeding_unit_id]=#{seeding_unit_id}include=barcodes,seeding_unit")
      end

      def completions
        client.oauth_token.get("/api/v3/facilities/#{@facility_id}/completions?filter[crop_batch_ids][]=#{@batch_id}")
      end

      delegate :client, to: :account

      def account
        @account ||= Account.find_by(artemis_id: @artemis_id)
      end

      def validate!
        raise 'FACILITY_ID must be specified' if @facility_id.nil?

        raise 'BATCH_ID must be specified' if @batch_id.nil?

        raise 'ARTEMIS_ID must be specified' if @artemis_id.nil?
      end
    end
  end
end
