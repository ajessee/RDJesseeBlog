FactoryBot.define do
  factory :user do
    name { "Andre Jessee" }
    email { "andre@andre.com" }
    password { "password" }
    password_confirmation { "password" }
  end
end
