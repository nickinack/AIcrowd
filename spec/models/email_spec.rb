# == Schema Information
#
# Table name: emails
#
#  id                      :integer          not null, primary key
#  model_id                :integer
#  mailer_classname        :string
#  recipients              :text
#  options                 :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  email_preferences_token :string
#  token_expiration_dttm   :datetime
#  participant_id          :integer
#  options_json            :jsonb
#  mailer_id               :integer
#  state                   :string
#
# Indexes
#
#  index_emails_on_mailer_id  (mailer_id)
#
# Foreign Keys
#
#  fk_rails_...  (mailer_id => mailers.id)
#

require 'rails_helper'

describe Email do
  context 'fields' do
    it { is_expected.to respond_to :model_id }
    it { is_expected.to respond_to :mailer_classname }
    it { is_expected.to respond_to :recipients }
    it { is_expected.to respond_to :options }
    it { is_expected.to respond_to :state }
    it { is_expected.to respond_to :email_preferences_token }
    it { is_expected.to respond_to :token_expiration_dttm }
    it { is_expected.to respond_to :options_json }
    it { is_expected.to respond_to :mailer_id }
  end

  context 'associations' do
    it { is_expected.to belong_to(:mailer) }
    it { is_expected.to belong_to(:participant) }
    it { is_expected.to have_many(:email_transitions) }
  end

  context 'validations' do
    it { is_expected.to validate_presence_of(:mailer_classname) }
    it { is_expected.to validate_presence_of(:recipients) }
    it { is_expected.to validate_presence_of(:state) }
  end
end
