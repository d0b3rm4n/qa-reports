# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20101016112255) do

  create_table "meego_test_cases", :force => true do |t|
    t.integer "meego_test_set_id",                     :null => false
    t.string  "name",                                  :null => false
    t.integer "result",                                :null => false
    t.string  "comment",               :default => ""
    t.integer "meego_test_session_id", :default => 0,  :null => false
  end

  create_table "meego_test_sessions", :force => true do |t|
    t.string   "environment",                       :default => ""
    t.string   "hardware",                          :default => ""
    t.string   "xmlpath",                           :default => ""
    t.string   "title",                                                :null => false
    t.string   "target",                            :default => ""
    t.string   "testtype",                          :default => ""
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "objective_txt",     :limit => 4000, :default => ""
    t.text     "build_txt",         :limit => 4000, :default => ""
    t.text     "qa_summary_txt",    :limit => 4000, :default => ""
    t.text     "issue_summary_txt", :limit => 4000, :default => ""
    t.boolean  "published",                         :default => false
    t.text     "environment_txt",   :limit => 4000, :default => ""
    t.datetime "tested_at",                                            :null => false
    t.integer  "author_id",                         :default => 0,     :null => false
    t.integer  "editor_id",                         :default => 0,     :null => false
    t.integer  "total_cases",                       :default => 0,     :null => false
    t.integer  "total_pass",                        :default => 0,     :null => false
    t.integer  "total_fail",                        :default => 0,     :null => false
    t.integer  "total_na",                          :default => 0,     :null => false
  end

  create_table "meego_test_sets", :force => true do |t|
    t.integer "meego_test_suite_id",                 :null => false
    t.string  "feature",             :default => ""
    t.integer "total_cases",         :default => 0,  :null => false
    t.integer "total_pass",          :default => 0,  :null => false
    t.integer "total_fail",          :default => 0,  :null => false
    t.integer "total_na",            :default => 0,  :null => false
  end

end
