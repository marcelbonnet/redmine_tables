module CustomTables
  module Patches
    module CustomFieldPatch
      def self.included(base)
        base.class_eval do

          after_save :update_tracker

          def update_tracker
            return unless self.type == "CustomEntityCustomField"

            self.custom_table.trackers.each do |t|
              t.custom_entity_custom_fields << self
              t.validate!
              t.save
            end
          end

        end
      end
    end
  end
end

CustomField.send(:include, CustomTables::Patches::CustomFieldPatch)