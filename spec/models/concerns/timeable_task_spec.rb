describe TimeableTask do
  class SomeTimedTask < GenericTask
    include TimeableTask

    def when_timer_ends; end

    def self.timer_delay
      5.days
    end
  end
  class AnotherTimedTask < GenericTask
    include TimeableTask

    def when_timer_ends; end
  end

  before do
    Timecop.freeze(Time.zone.today)
  end

  after do
    Timecop.return
  end

  let(:appeal) { create(:appeal) }

  it "creates a task timer with the correct delay when we create some timed task" do
    task = SomeTimedTask.create!(appeal: appeal, assigned_to: Bva.singleton)
    timers = TaskTimer.where(task: task)
    expect(timers.length).to eq(1)
    expect(timers.first.submitted_at).to eq(Time.zone.today + 5.days)
  end

  context "when not correctly configured" do
    subject { AnotherTimedTask.create!(appeal: appeal, assigned_to: Bva.singleton) }

    it "errors if we do not pass a timer delay" do
      expect { subject }.to raise_error(Caseflow::Error::MissingTimerMethod)
    end
  end
end
