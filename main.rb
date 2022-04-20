require 'sidekiq-pro'

class Callbacks
  def step1_done(status, options)
    puts 'Step 1 callback started'
    overall = Sidekiq::Batch.new(status.parent_bid)
    overall.jobs do
      step2 = Sidekiq::Batch.new
      step2.on(:success, 'Callbacks#step2_done')
      step2.jobs do
        B.perform_async
        C.perform_async
      end
    end
  end

  def step2_done(status, options)
    puts 'Step 2 callback started'
  end
  
  def workflow_complete(status, options)
    puts 'The workflow is complete'
  end
end

class StartWorkflow
  include Sidekiq::Job

  def perform
    batch.jobs do
      step1 = Sidekiq::Batch.new
      step1.on(:success, 'Callbacks#step1_done')  
      step1.jobs do
        A.perform_async
      end
    end
  end
end

class A
  include Sidekiq::Job

  def perform
    puts 'Running "A"'
  end
end

class B
  include Sidekiq::Job

  def perform
    puts 'Running "B"'
  end
end

class C
  include Sidekiq::Job

  def perform
    puts 'Running "C"'
  end
end

Sidekiq.configure_server do
  overall = Sidekiq::Batch.new
  overall.on(:complete, 'Callbacks#workflow_complete')
  overall.jobs do
    StartWorkflow.perform_async
  end
end