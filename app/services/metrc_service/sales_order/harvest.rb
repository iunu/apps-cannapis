module MetrcService
  module SalesOrder
    class Harvest < MetrcService::SalesOrder::Base
      def call
        call_metrc(:create_transfer_template, build_create_transfer_template_payload)

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_sales_order_batch)
      end

      def build_create_transfer_template_payload
        [
          {
            Name: batch.arbitrary_id,
            TransporterFacilityLicenseNumber: nil,
            DriverOccupationalLicenseNumber: nil,
            DriverName: nil,
            DriverLicenseNumber: nil,
            PhoneNumberForQuestions: nil,
            VehicleMake: nil,
            VehicleModel: nil,
            VehicleLicensePlateNumber: nil,
            Destinations: destinations.map { |destination| build_destination_payload(destination) }
          }
        ]
      end

      def destinations
        # TODO
      end

      def build_destination_payload(_destination)
        {
          RecipientLicenseNumber: '123-XYZ',
          TransferTypeName: 'Transfer',
          PlannedRoute: 'I will drive down the road to the place.',
          EstimatedDepartureDateTime: '2018-03-06T09:15:00.000',
          EstimatedArrivalDateTime: '2018-03-06T12:24:00.000',
          Transporters: transporters.map { |transporter| build_transporter_payload(transporter) }
        }
      end

      def transporters
        # TODO
      end

      def build_transporter_payload(_transporter)
        {
          TransporterFacilityLicenseNumber: '123-ABC',
          DriverOccupationalLicenseNumber: '50',
          DriverName: 'X',
          DriverLicenseNumber: '5',
          PhoneNumberForQuestions: '18005555555',
          VehicleMake: 'X',
          VehicleModel: 'X',
          VehicleLicensePlateNumber: 'X',
          IsLayover: false,
          EstimatedDepartureDateTime: '2018-03-06T12:00:00.000',
          EstimatedArrivalDateTime: '2018-03-06T21:00:00.000',
          TransporterDetails: nil
        }
      end
    end
  end
end
