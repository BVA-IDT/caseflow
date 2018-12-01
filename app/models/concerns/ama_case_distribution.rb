# rubocop:disable Metrics/ModuleLength
module AmaCaseDistribution
  extend ActiveSupport::Concern

  private

  def ama_distribution
    priority_count # count the number of priority appeals before we start distributing anything
    @cases = []
    @rem = batch_size
    @remaining_docket_proportions = docket_proportions.clone

    distribute_appeals(:legacy, @rem, priority: true, genpop: "not_genpop")
    distribute_appeals(:hearing, @rem, priority: true, genpop: "not_genpop")
    distribute_appeals(:legacy, @rem, priority: false, genpop: "not_genpop", range: legacy_docket_range)
    distribute_appeals(:hearing, @rem, priority: false, genpop: "not_genpop")

    priority_rem = (priority_target - @cases.count(&:priority)).clamp(0, @rem)
    oldest_priority_appeals_by_docket(priority_rem).each { |docket, n| distribute_appeals(docket, n, priority: true) }

    deduct_distributed_actuals_from_remaining_docket_proportions(:legacy, :hearing)

    until @rem == 0 || @remaining_docket_proportions.all? { |_, p| p == 0 }
      distribute_appeals_according_to_remaining_docket_proportions
    end

    @cases
  end

  def distribute_appeals(docket, n, priority: false, genpop: "any", range: nil)
    if range.nil?
      cases = dockets[docket].distribute_appeals(self, priority: priority, genpop: genpop, limit: n)
    elsif docket == :legacy && priority == false
      cases = dockets[:legacy].distribute_nonpriority_appeals(self, genpop: genpop, range: range, limit: n)
    else
      return
    end

    @cases += cases
    @rem -= cases.count

    cases
  end

  def deduct_distributed_actuals_from_remaining_docket_proportions(*args)
    args.each do |docket|
      nonpriority_count = batch_size - @cases.count(&:priority)
      docket_count = @cases.count { |c| c.docket == docket.to_s && !c.priority }
      p = docket_count / nonpriority_count
      @remaining_docket_proportions[docket] = [@remaining_docket_proportions[docket] - p, 0].max
    end
  end

  def distribute_appeals_according_to_remaining_docket_proportions
    @remaining_docket_proportions = normalize_proportions(@remaining_docket_proportions)
    docket_targets = stochastic_allocation(@rem, @remaining_docket_proportions)

    docket_targets.each do |docket, n|
      cases = distribute_appeals(docket, n, priority: false)
      @remaining_docket_proportions[docket] = 0 if cases.count < n
    end
  end

  # CMGTODO
  def ama_statistics; end

  def dockets
    @dockets ||= {
      legacy: LegacyDocket.new,
      direct_review: AmaDirectReviewDocket.new,
      evidence_submission: AmaEvidenceSubmissionDocket.new,
      hearing: AmaHearingDocket.new
    }
  end

  def priority_count
    @priority_count ||= dockets
      .values
      .map { |docket| docket.count(priority: true, ready: true) }
      .reduce(0, :+)
  end

  def priority_target
    proportion = [priority_count.to_f / total_batch_size, 1.0].min
    (proportion * batch_size).ceil
  end

  def legacy_docket_range
    [(total_batch_size - priority_count) * docket_proportions[:legacy], 0].max.round
  end

  def oldest_priority_appeals_by_docket(n)
    return {} if n == 0

    dockets.map { |sym, docket| docket.age_of_n_oldest_priority_appeals(n).map { |age| [age, sym] } }
      .flatten
      .sort_by { |a| a[0] }
      .first(n)
      .each_with_object(Hash.new(0)) { |a, counts| counts[a[1]] += 1 }
  end

  # CMGTODO
  def docket_proportions
    @docket_proportions ||= normalize_proportions(dockets.transform_values(&:weight))
  end

  def normalize_proportions(proportions)
    total = proportions.values.reduce(0, :+)
    proportions.transform_values { |p| p * (1.0 / total) }
  end

  def stochastic_allocation(n, proportions)
    result = proportions.transform_values { |p| (n * p).floor }
    rem = n - result.values.reduce(0, :+)

    return result if rem == 0

    iterations = rem

    catch :complete do
      proportions.each_with_index do |(docket, p), i|
        if i == proportions.count - 1
          result[docket] += rem
          throw :complete
        end

        probability = (n * p).modulo(1) / iterations

        iterations.times do
          next unless probability > rand

          result[docket] += 1
          rem -= 1

          throw :complete if rem == 0
        end
      end
    end

    result
  end
end
# rubocop:enable Metrics/ModuleLength