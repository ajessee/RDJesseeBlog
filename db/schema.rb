# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_09_12_041500) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "comments", id: :serial, force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "commentable_id"
    t.string "commentable_type"
    t.integer "user_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "email_responses", id: :serial, force: :cascade do |t|
    t.string "email"
    t.text "extra_info"
    t.integer "response_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pictures", id: :serial, force: :cascade do |t|
    t.text "caption"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "imageable_id"
    t.string "imageable_type"
    t.integer "user_id"
    t.integer "year"
    t.string "path"
    t.string "content_type"
    t.string "file_name"
    t.index ["imageable_type", "imageable_id"], name: "index_pictures_on_imageable_type_and_imageable_id"
    t.index ["user_id"], name: "index_pictures_on_user_id"
  end

  create_table "recordings", id: :serial, force: :cascade do |t|
    t.text "caption"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.string "recording"
    t.integer "recordable_id"
    t.string "recordable_type"
    t.index ["user_id"], name: "index_recordings_on_user_id"
  end

  create_table "stories", id: :serial, force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year_written"
    t.integer "decade"
    t.string "location"
    t.string "genre"
    t.integer "word_count"
    t.string "life_stage"
    t.string "category"
    t.string "path"
    t.string "content_type"
    t.string "file_name"
    t.index ["user_id", "created_at"], name: "index_stories_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_stories_on_user_id"
  end

  create_table "taggings", id: :serial, force: :cascade do |t|
    t.integer "story_id"
    t.integer "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["story_id"], name: "index_taggings_on_story_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", id: :serial, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.string "remember_digest"
    t.boolean "admin", default: false
    t.string "activation_digest"
    t.boolean "activated", default: false
    t.datetime "activated_at"
    t.string "reset_digest"
    t.datetime "reset_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "videos", id: :serial, force: :cascade do |t|
    t.text "caption"
    t.string "youtube_url"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "youtube"
    t.integer "year"
    t.string "video"
    t.integer "videoable_id"
    t.string "videoable_type"
    t.index ["user_id"], name: "index_videos_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "users"
  add_foreign_key "pictures", "users"
  add_foreign_key "recordings", "users"
  add_foreign_key "stories", "users"
  add_foreign_key "taggings", "stories"
  add_foreign_key "taggings", "tags"
  add_foreign_key "videos", "users"
end
