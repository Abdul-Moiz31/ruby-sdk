# frozen_string_literal: true

RSpec.describe "requiring the gem by its gem name" do
  it 'loads via require "infisical-sdk", as Bundler.require does in Rails apps' do
    expect { require "infisical-sdk" }.not_to raise_error
    expect(defined?(Infisical::Client)).to eq("constant")
  end
end
