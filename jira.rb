require 'colorize'
require 'tty-prompt'
require 'pry'
require 'yaml'

def JIRA
  YAML.load_file(File.join(File.expand_path('~'), ".jira.d/custom.yaml"))
end

def jira_items 
  `jira list --query='assignee = currentUser() AND resolution = Unresolved and Sprint in openSprints() order by updated DESC'`.split("\n")
end

def print_jira_list 
  jira_items.each do |item| 
    ticket, message = item.split(" ", 2)
    ticket=ticket.tr(":", "")
    puts "https://jira.corp.stripe.com/browse/#{ticket.colorize(:blue)} #{message} "
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
  prompt = TTY::Prompt.new(active_color: :cyan, enable_color: true)

  user = ENV["USER"]
  
  branch_regex = %r{.*#{user}-(?<jira>.*)/(?<title>.*)$}
  
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
end

def new_branch
  jiras=["New-Jira", "None"].concat(jira_items)
  prompt = TTY::Prompt.new(active_color: :cyan, enable_color: true)

  selection=prompt.select('What are you working on?', jiras)
  
  if selection == "None"
    branch_name=prompt.ask('Name?')
    
    `git checkout -b #{branch_name.tr(" ", "_")}`
  elsif selection == "New-Jira"
    title=prompt.ask('Ticket title?')
    _, jira_ticket, link =`jira create -p #{JIRA["project"]} -o "summary=#{title}"  -o "components=#{JIRA["component"]}"  --noedit`.split(" ")
    puts link
    `git checkout -b $USER-#{jira_ticket}/#{title.tr(" ", "_")[0..40]}`  
  else 
    jira_ticket, message=selection.split(" ", 2)
    
    x = prompt.ask("Branch title? (#{message})")
    if !x.nil?
      message=x
    end
    
    `git checkout -b $USER-#{jira_ticket.tr(":", "")}/#{message.tr(" ", "_")[0..40]}`
  end
end
