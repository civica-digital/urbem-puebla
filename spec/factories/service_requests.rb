# Read about factories at https://github.com/thoughtbot/factory_girl
require 'ffaker'

FactoryGirl.define do
  factory :service_request do
    service
    status
    public_servant
    association :requester, factory: :user
    address     { FFaker::Lorem.words(3) }
    description { FFaker::Lorem.paragraph(2) }
  end
end
