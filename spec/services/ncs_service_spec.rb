require 'rails_helper'

RSpec.describe NcsService do
  let(:ctx) do
    {
      id: 3000,
      relationships: {
        batch: { data: { id: 2002 } },
        facility: { data: { id: 1568 } }
      },
      completion_id: 1001
    }.with_indifferent_access
  end

  describe '::CROP' do
    subject { described_class::CROP }

    it { is_expected.not_to be_empty }
    it { is_expected.to eq 'Cannabis' }
  end

  describe 'module lookup' do
    let(:account) { create(:account) }
    let(:integration) { create(:integration, :ncs_vendor, account: account) }
    let(:task) { create(:task, integration: integration) }
    let(:instance) { described_class::Lookup.new(ctx, integration) }
    let(:seeding_unit) { double(:seeding_unit, name: seeding_unit_name) }
    let(:completion) { double(:completion) }

    before do
      allow(instance)
        .to receive(:seeding_unit)
        .and_return(seeding_unit)

      allow(instance)
        .to receive(:completion)
        .and_return(completion)
    end

    describe '#module_name_for_seeding_unit' do
      subject { instance.send(:module_name_for_seeding_unit) }

      describe 'plants_barcoded' do
        let(:seeding_unit_name) { 'Plants (Barcoded)' }
        it { is_expected.to eq('plant') }
      end

      describe 'plants_clone' do
        let(:seeding_unit_name) { 'Plants (Clone)' }
        it { is_expected.to eq('plant') }
      end

      describe 'package' do
        let(:seeding_unit_name) { 'Package' }
        it { is_expected.to eq('package') }
      end

      describe 'testing_package' do
        let(:seeding_unit_name) { 'Testing Package' }
        it { is_expected.to eq('package') }
      end

      describe 'sales_order' do
        let(:seeding_unit_name) { 'Sales Order' }
        it { is_expected.to eq('sales_order') }
      end
    end

    describe '#module_for_completion' do
      let(:action_type) { 'start' }

      let(:completion) { double(:completion, action_type: action_type) }

      subject { instance.send(:module_for_completion) }

      describe 'plant_clone' do
        let(:seeding_unit_name) { 'Plants (Clone)' }

        it { is_expected.to eq(NcsService::Plant::Start) }
      end

      describe 'package' do
        let(:seeding_unit_name) { 'Package' }

        it { is_expected.to eq(NcsService::Package::Start) }
      end

      describe 'testing_package' do
        let(:seeding_unit_name) { 'Testing Package' }

        it { is_expected.to eq(NcsService::Package::Start) }
      end

      describe 'sales_order' do
        let(:action_type) { 'move' }
        let(:seeding_unit_name) { 'Sales Order' }

        it 'fails with an error' do
          expect { subject }.to raise_error(InvalidOperation)
        end
      end
    end
  end

  describe '#run_now?' do
    let(:integration) { create(:integration, eod: "#{Time.now.hour}:00") }
    let(:ctx) { double(:ctx) }
    let(:ref_time) { Time.now.localtime(integration.timezone) }

    before do
      expect_any_instance_of(NcsService::Lookup)
        .to receive(:module_for_completion)
        .and_return(target_module)
    end

    subject { described_class.run_now?(ctx, integration) }

    context 'when it should execute immediately' do
      let(:target_module) do
        Class.new(NcsService::Base) do
          run_mode :now
        end
      end

      it { is_expected.to eq(true) }
    end

    context 'when it should schedule execution for later' do
      context 'by default' do
        let(:target_module) { Class.new(NcsService::Base) }

        it { is_expected.to eq(false) }
      end

      context 'by design' do
        let(:target_module) do
          Class.new(NcsService::Base) do
            run_mode :later
          end
        end

        it { is_expected.to eq(false) }
      end
    end
  end
end
