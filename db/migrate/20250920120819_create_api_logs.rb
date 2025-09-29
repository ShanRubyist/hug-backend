class CreateApiLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :api_logs, id: :uuid do |t|
      t.uuid :ai_call_id, null: false
      t.json :input, null: false
      t.json :data

      t.timestamps
    end
  end
end
