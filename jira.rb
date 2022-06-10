require 'colorize'
require 'tty-prompt'
require 'pry'
require 'yaml'

JIRA=YAML.load_file(File.join(File.expand_path('~'), ".jira.d/custom.yaml"))

JIRA_CONFIG = YAML.load_file(File.join(File.expand_path('~'), ".jira.d/config.yml"))

def jira_items
  `jira list --query='assignee = currentUser() AND status not in ("Done",  "Deploy Needed", "Verification Needed" ) and status != "BACKLOG" order by updated DESC'`.split("\n")
end

def print_jira_list
  jira_items.each do |item|
    ticket, message = item.split(" ", 2)
    ticket=ticket.tr(":", "")
    puts "#{JIRA_CONFIG["endpoint"]}/browse/#{ticket.colorize(:blue)} #{message} "
  end
end

def new_jira
    prompt = TTY::Prompt.new(active_color: :cyan, enable_color: true)

    title=prompt.ask('Ticket title?')
    _, jira_ticket, link =`jira create -p #{JIRA["project"]} -o "summary=#{title}" -o "components=#{JIRA["component"]}" --noedit`.split(" ")
    puts link
end

# resumes a ticket
def resume_jira
  begin
    prompt = TTY::Prompt.new(active_color: :cyan, enable_color: true)

    user = ENV["USER"]

    branch_regex = %r{.*#{user}-(?<jira>.*?)/(?<title>.*)$}

    existing_git_branches = {}

    # list all branches formatted by branch name and aggregate them
    `git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)'`.split("\n").each do |branch|
      branch.strip!

      if matches = branch_regex.match(branch)
        if existing_git_branches[matches[:jira]].nil?
          existing_git_branches[matches[:jira]] = []
        end

        existing_git_branches[matches[:jira]].push({
            :jira => matches[:jira],
            :branch => branch,
            :title => matches[:title],
        })
      end
    end

    # filter all jiras that have existing branches
    jiras_with_branches = jira_items.select do |item|
      target_ticket, _ = item.split(" ", 2)

      cleaned_branch = target_ticket.gsub(":", "")

      !existing_git_branches[cleaned_branch].nil?
    end

    if jiras_with_branches.size == 0
      puts "No working branches"
      puts "Active jiras are #{jira_items}"
      return
    end

    selection=prompt.select('Resume?', jiras_with_branches)

    target_ticket, _ = selection.split(" ", 2)
    target_ticket = target_ticket.gsub(":", "")

    branch_to_use = ""

    # find which branch to use given the jira
    jiras_with_branches.each do |item|
      ticket, _ = item.split(" ", 2)
      ticket = ticket.gsub(":", "")

      if target_ticket == ticket
        existing = existing_git_branches[target_ticket]
        if existing.nil?
          puts "No branches exist"
        elsif existing.length == 1
          branch_to_use = existing[0][:branch]
        else

          names = existing.map do |b|
            b[:branch]
          end

          branch_to_use=prompt.select('Branch?', names)
        end
      end
    end

    if branch_to_use != ""
      `git checkout #{branch_to_use}`
    end
  rescue TTY::Reader::InputInterrupt
  end
end

def safe_trim(arg)
  "'\",:;.!@#\{$%^&*()}<>?[]+".each_char { |replace| arg = arg.tr(replace, '')  }

  return arg.tr(" ", "_").tr("/","_")[0..40]
end

def new_branch
  begin
    jiras=["New-Jira", "None"].concat(jira_items)
    prompt = TTY::Prompt.new(active_color: :cyan, enable_color: true)

    selection=prompt.select('What are you working on?', jiras)

    if selection == "None"
      branch_name=prompt.ask('Name?')

      `git checkout -b #{branch_name.tr(" ", "_")}`
    elsif selection == "New-Jira"
      title=prompt.ask('Ticket title?')
      _, jira_ticket, link =`jira create -p #{JIRA["project"]} -o "summary=#{title}" --noedit -t edit.yml`.split(" ")
      puts link
      `git checkout -b $USER-#{jira_ticket}/#{safe_trim(title)}`
    else
      jira_ticket, message=selection.split(" ", 2)

      x = prompt.ask("Branch title? (#{message})")
      if !x.nil?
        message=x
      end

      `git checkout -b $USER-#{jira_ticket.tr(":", "")}/#{safe_trim(message)}`
    end
  rescue TTY::Reader::InputInterrupt
  end
end
