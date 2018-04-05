class CreateClaimEstablishments < ActiveRecord::Migration[5.1]
  def change
    create_table :claim_establishments do |t|
      t.integer :task_id
      t.integer :decision_type
      t.datetime :decision_date

      t.timestamps null: false
    end
  end
end
