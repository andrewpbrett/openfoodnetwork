# frozen_string_literal: true

# Here we clone (or find a clone of)
#   - a card (card_*) or payment_method (pm_*) stored (in a customer) in a platform account into
#   - a payment method (pm_*) (in a new customer) in a connected account
#
# This is required when using the Stripe Payment Intents API:
#   - the customer and payment methods are stored in the platform account
#       so that they can be re-used across multiple sellers
#   - when a card needs to be charged, we need to clone (or find the clone)
#       in the seller's stripe account
#
# To avoid creating a new clone of the card/customer each time the card is charged or
# authorized (e.g. for SCA), we attach metadata { clone: true } to the card the first time we
# clone it and look for a card with the same fingerprint (hash of the card number) and
# that metadata key to avoid cloning it multiple times.

module Stripe
  class CreditCardCloner
    def find_or_clone(card, connected_account_id)
      if card.user && cloned_card = find_cloned_card(card, connected_account_id)
        cloned_card
      else
        clone(card, connected_account_id)
      end
    end

    def destroy_clones(card)
      card.user.customers.each do |customer|
        next unless stripe_account = customer.enterprise.stripe_account&.stripe_user_id

        customer_id, _payment_method_id = find_cloned_card(card, stripe_account)
        next unless customer_id

        customer = Stripe::Customer.retrieve(customer_id, stripe_account: stripe_account)
        customer&.delete unless customer.deleted?
      end
    end

    private

    def clone(credit_card, connected_account_id)
      new_payment_method = clone_payment_method(credit_card, connected_account_id)

      # If no customer is given, it will clone the payment method only
      return [nil, new_payment_method.id] if credit_card.gateway_customer_profile_id.blank?

      new_customer = Stripe::Customer.create({ email: credit_card.user.email },
                                             stripe_account: connected_account_id)
      attach_payment_method_to_customer(new_payment_method.id,
                                        new_customer.id,
                                        connected_account_id)

      add_metadata_to_payment_method(new_payment_method.id, connected_account_id)

      [new_customer.id, new_payment_method.id]
    end

    def find_cloned_card(card, connected_account_id)
      return nil unless fingerprint = fingerprint_for_card(card)

      find_customers(card.user.email, connected_account_id).each do |customer|
        find_payment_methods(customer.id, connected_account_id).each do |payment_method|
          if payment_method_is_clone?(payment_method, fingerprint)
            return [customer.id, payment_method.id]
          end
        end
      end
      nil
    end

    def payment_method_is_clone?(payment_method, fingerprint)
      payment_method.card.fingerprint == fingerprint && payment_method.metadata["ofn-clone"]
    end

    def fingerprint_for_card(card)
      Stripe::PaymentMethod.retrieve(card.gateway_payment_profile_id).card.fingerprint
    end

    def find_customers(email, connected_account_id)
      start_after, customers = nil, []

      (1..request_limit = 100).each do |request_number|
        response = Stripe::Customer.list({ email: email, starting_after: start_after, limit: 100 },
                                         stripe_account: connected_account_id)
        customers += response.data
        break unless response.has_more

        start_after = response.data.last.id
        notify_limit(request_number, "customers") if request_limit == request_number
      end
      customers
    end

    def find_payment_methods(customer_id, connected_account_id)
      start_after, payment_methods = nil, []

      (1..request_limit = 10).each do |request_number|
        options = { customer: customer_id, type: 'card', starting_after: start_after, limit: 100 }
        response = Stripe::PaymentMethod.list(options, stripe_account: connected_account_id)
        payment_methods += response.data
        break unless response.has_more

        start_after = response.data.last.id
        notify_limit(request_number, "payment methods") if request_limit == request_number
      end
      payment_methods
    end

    def notify_limit(request_number, retrieving)
      Bugsnag.notify("Reached limit of #{request_number} requests retrieving #{retrieving}.")
    end

    def clone_payment_method(credit_card, connected_account_id)
      platform_acct_payment_method_id = credit_card.gateway_payment_profile_id
      customer_id = credit_card.gateway_customer_profile_id

      Stripe::PaymentMethod.create({ customer: customer_id,
                                     payment_method: platform_acct_payment_method_id },
                                   stripe_account: connected_account_id)
    end

    def attach_payment_method_to_customer(payment_method_id, customer_id, connected_account_id)
      Stripe::PaymentMethod.attach(payment_method_id,
                                   { customer: customer_id },
                                   stripe_account: connected_account_id)
    end

    def add_metadata_to_payment_method(payment_method_id, connected_account_id)
      Stripe::PaymentMethod.update(payment_method_id,
                                   { metadata: { "ofn-clone": true } },
                                   stripe_account: connected_account_id)
    end
  end
end
