module Api
  module V1
    module Admin
      class ConsolidationCenterController < ApplicationController
        # include ExceptionHandler
        # include ShipmentScanable
        # include ReturnHelper

        RETURN_TO_SCAN_PAGE = %w[mark_as_processed mark_as_dropped mark_as_to_be_inspected mark_as_return_processed mark_as_liquidated mark_as_bad_label]

        wrap_parameters false
        # rescue_from StandardError, with: :rescue_exception

        # before_action -> { validate_action("editShipmentConsolidationCenterState") }
        # before_action :validate_consolidation_center, except: [:list, :search]
        # before_action :set_shipment_from_barcode, only: :scan
        before_action :set_shipment, only: [:update_consolidation_center_state, :return_label, :revert_consolidation_center_state]
        # before_action -> { @shipment.check_and_update_flags }, only: [:scan, :update_consolidation_center_state]
        before_action :validate_consolidation_center_event, only: :update_consolidation_center_state
        before_action :validate_weight_dimensions_params, only: :update_consolidation_center_state
        before_action :validate_weight_dimensions_unit, only: :update_consolidation_center_state
        # before_action :validate_confirm_params, only: :drop_confirm
        before_action :set_return_shipment, only: :return_label

        def list
          @consolidation_centers = ConsolidationCenter.all
          # @consolidation_centers = params[:all] ? ConsolidationCenter.all : ConsolidationCenter.where(admin_name: current_user.authorized_consolidation_center_admin_names)
          # [{ a: 1, b: 2, c: 3 }]
        end

        def search
          params_builder = ::ConsolidationCenterService::SearchParamsBuilder.new(search_params)
          params_builder.validate!
          @shipments = Shipment.search("*", params_builder.search_options).results
        end

        def scan
          if @shipment.consolidation_center_not_received?
            @shipment.scan_as_received!(@consolidation_center.admin_name, easyship_comments)
          end
        end

        def update_consolidation_center_state
          set_weight_dimensions
          @shipment.send("#{@consolidation_center_event}!", @consolidation_center.admin_name, easyship_comments)

          if @consolidation_center_event.in?(RETURN_TO_SCAN_PAGE)
            render json: {return_to_scan_page: true}.to_json, status: :ok
          else
            render "api/v1/admin/consolidation_center/scan", status: :ok
          end
        end

        def revert_consolidation_center_state
          # todo later: extra security to be added for revert
          # todo later: extra security to be added for revert

          # todo later: extra security to be added for revert
          # todo later: extra security to be added for revert

          # todo later: extra security to be added for revert

          content = "consolidation_center_state reverted from #{@shipment.consolidation_center_state} to #{revert_to_aasm_state} by action revert_consolidation_center_state"

          ActiveRecord::Base.transaction do
            # todo later: create log
            # todo later: create status record
            @shipment.update_columns(last_status_message_id: params[:revert_to_status_message_id], consolidation_center_state: params[:revert_to_aasm_state], updated_at: Time.now.utc)
          end


          render "api/v1/admin/consolidation_center/scan", status: :ok
        end

        def return_label
          render json: {return_label_url: @return_shipment.get_public_label_url(page_size: "4x6")}, status: :ok
        end

        def drop_prepare
          # waiting_to_be_dropped = prepare_shipments.map do |c|
          #   {
          #     courier_id: c[0],
          #     courier_name: c[1],
          #     shipments_count: c[2],
          #     total_actual_weight_lb: kg_to_lb(c[3]).to_f.round(1)
          #   }
          # end
          waiting_to_be_dropped = []

          render json: {waiting_to_be_dropped: waiting_to_be_dropped}, status: :ok
        end

        def drop_confirm
          # binding.pry
          # ActiveRecord::Base.transaction do
          #   update_shipments
          #   create_status_records
          # end
          # LogMessages::BulkCreateWorker.perform_async("Shipment", confirm_shipments_ids, "aasm", "consolidation_center_state changed from processed to dropped by action drop", current_user.id)
          # reindex_shipments
          confirm_shipments_ids = 1
          render json: {message: "#{confirm_shipments_ids.size} shipments have been marked as dropped"}, status: :ok
        end

        private

        def search_params
          params.permit(:tracking_number, :destination_name, :destination_country_id)
        end

        def set_weight_dimensions
          scanned_weight_dimensions = weight_dimensions_params.to_h
          scanned_weight_dimensions = scanned_weight_dimensions.except("weight_unit", "actual_weight") unless weight_available?
          scanned_weight_dimensions = scanned_weight_dimensions.except("dimensions_unit", "length", "width", "height") unless dimensions_available?
          return unless scanned_weight_dimensions
          @shipment.order_data = Hash(@shipment.order_data).merge(scanned_weight_dimensions: scanned_weight_dimensions)
        end

        def weight_dimensions_params
          params.permit(:actual_weight, :length, :width, :height, :weight_unit, :dimensions_unit)
        end

        def set_return_shipment
          @return_shipment = get_return_shipment || create_return_shipment
          raise StandardError, "The return label could not be generated" unless @return_shipment
        end

        def get_return_shipment
          # get shipping label if already generated
        end

        def create_return_shipment
          # generate shipping label from preferred TMS
        end

        def shipments_to_drop
          shipments = Shipment.unscope(:order).where(consolidation_center_state: "processed")

          if @consolidation_center.old_admin_name
            # Note: to deprecate
            shipments.where(
              "order_data @> ? OR order_data @> ?",
              {consolidation_center: @consolidation_center.admin_name}.to_json,
              {consolidation_center: @consolidation_center.old_admin_name}.to_json
            )
          else
            shipments.where("order_data @> ?", {consolidation_center: @consolidation_center.admin_name}.to_json)
          end
        end

        def prepare_shipments
          shipments_to_drop
            .joins(:courier)
            .group("couriers.id")
            .pluck("couriers.id, couriers.name, COUNT(shipments.id), SUM(shipments.total_actual_weight)")
        end

        def confirm_shipments_ids
          @_confirm_shipments_ids ||= shipments_to_drop
            .where(courier_id: params[:courier_id])
            .ids
        end

        def update_shipments
          attributes = %{
            updated_at = '#{Time.now.utc}',
            consolidation_center_state = 'dropped',
            order_data = jsonb_set(order_data, '{bol_number}', '\"#{params[:bol_number]}\"')

          }

          confirm_shipments_ids.each_slice(1000) do |batch_shipment_ids|
            Shipment.where(id: batch_shipment_ids).unscope(:order).update_all(attributes) # Note: reindex is done outside of the transaction
          end
        end

        def reindex_shipments
          Shipment.none.reindex_all(confirm_shipments_ids)
        end

        def easyship_comments
          weight = "#{weight_dimensions_params[:actual_weight]} #{weight_dimensions_params[:weight_unit]}" if weight_available?
          dimensions = "#{weight_dimensions_params[:length]}x#{weight_dimensions_params[:width]}x#{weight_dimensions_params[:height]} #{weight_dimensions_params[:dimensions_unit]}" if dimensions_available?
          bol_number = "BOL Number: #{params[:bol_number]}" if params[:bol_number]
          [@consolidation_center.admin_name, params[:message], weight, dimensions, bol_number].compact.join(" - ").presence
        end

        def create_status_records
          columns = [:user_id, :shipment_id, :status_message_id, :easyship_comments]
          values = confirm_shipments_ids.map { |shipment_id| [current_user.id, shipment_id, 172, easyship_comments] }
          StatusRecord.import(columns, values, validate: false, batch_size: 1000)
        end

        def set_shipment
          @shipment = Shipment.find_by!(easyship_shipment_id: params[:easyship_shipment_id])
        end

        def validate_consolidation_center_event
          if @shipment.consolidation_center_events.include?(params[:consolidation_center_event].to_s.to_sym)
            return @consolidation_center_event = params[:consolidation_center_event].to_s
          end
          raise StandardError, "The action, #{params[:consolidation_center_event]}, is not permitted for this shipment"
        end

        def validate_consolidation_center
          raise StandardError, "Consolidation Center must be present. Please refresh the page" if params[:consolidation_center].blank?
          @consolidation_center = ConsolidationCenter.find_by_string(params[:consolidation_center]) if current_user.can_use_consolidation_center?(params[:consolidation_center])
          raise StandardError, "Consolidation Center #{params[:consolidation_center]} is not recognised. Please contact the Tech team" unless @consolidation_center
        end

        def validate_confirm_params
          raise StandardError, "BOL Number must be present" if params[:bol_number].blank?
          raise StandardError, "Courier Id must be present" if params[:courier_id].blank?
          raise StandardError, "No Shipments could be found" if confirm_shipments_ids.empty?
        end

        def validate_weight_dimensions_params
          return unless @consolidation_center_event == "mark_as_over_limit"
          return if weight_available? || dimensions_available?
          raise StandardError, "Weight or Dimensions must be present"
        end

        def validate_weight_dimensions_unit
          raise StandardError, "Weight Unit must be present" if weight_available? && !Measured::Weight.unit_or_alias?(weight_dimensions_params[:weight_unit])
          raise StandardError, "Dimensions Unit must be present" if dimensions_available? && !Measured::Length.unit_or_alias?(weight_dimensions_params[:dimensions_unit])
        end

        def weight_available?
          weight_dimensions_params[:actual_weight].to_f > 0
        end

        def dimensions_available?
          weight_dimensions_params[:length].to_f * weight_dimensions_params[:width].to_f * weight_dimensions_params[:height].to_f > 0
        end

        # def rescue_exception(e)
        #   ErrorNotification.notify(e)
        #   render json: {error: e.message}, status: :bad_request
        # end
      end
    end
  end
end
