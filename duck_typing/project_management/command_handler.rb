module ProjectManagement

  class Issue
    class InvalidTransition < StandardError; end
  end

  class CommandHandler
    def initialize(event_store)
      @event_store = event_store
    end

    def create(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:open)
        issue.open
        IssueOpened.new(data: {issue_id: cmd.id})
      end
    end

    def close(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:close)
        issue.close
        IssueClosed.new(data: {issue_id: cmd.id})
      end
    end

    def start(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:start)
        issue.start
        IssueProgressStarted.new(data: {issue_id: cmd.id})
      end
    end

    def stop(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:stop)
        issue.stop
        IssueProgressStopped.new(data: {issue_id: cmd.id})
      end
    end

    def reopen(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:reopen)
        issue.reopen
        IssueReopened.new(data: {issue_id: cmd.id})
      end
    end

    def resolve(cmd)
      load_issue(cmd.id) do |issue|
        raise_invalid unless issue.respond_to?(:resolve)
        issue.resolve
        IssueResolved.new(data: {issue_id: cmd.id})
      end
    end

    private

    def raise_invalid
      raise Issue::InvalidTransition
    end

    def stream_name(id)
      "Issue$#{id}"
    end

    def load_issue(id)
      version = -1
      issue = Issue.new
      @event_store.read.stream(stream_name(id)).each do |event|
        case event
        when IssueOpened
          issue = issue.open
        when IssueProgressStarted
          issue = issue.start
        when IssueProgressStopped
          issue = issue.stop
        when IssueResolved
          issue = issue.resolve
        when IssueReopened
          issue = issue.reopen
        when IssueClosed
          issue = issue.close
        end
        version += 1
      end
      events = yield issue
      publish(events, id, version)
    end

    def publish(events, id, version)
      @event_store.publish(
        events,
        stream_name: stream_name(id),
        expected_version: version
      )
    end
  end
end