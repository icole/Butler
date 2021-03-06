# Description
#   Allows users to find any open projects by skillset
#
# Commands
#   hubot do any projects need <phrase> - Finds any projects that require a skillset of <phrase>

_ = require 'lodash'

knownTech = [
  'html', 'css', 'less', 'saas', 'javascript', 'js', 'front end', 'back end', 'nodejs', 'node js',
  'rails', 'ruby', 'obj-c', 'objective c', 'objective-c', 'java',
  'android', 'jekyll', 'grunt', 'gulp', 'wordpress', 'bootstrap', 'c#', 'net',
  'django', 'python', 'php'
]

projectTypes =
  'website': ['html', 'css', 'javascript', 'js'],
  'web_app': ['html', 'css', 'javascript', 'js'],
  'mobile_app': ['ios', 'android', 'iphone', 'java', 'objc', 'objective c']

module.exports = (robot) ->
  projectPattern = new RegExp('projects .*(?:need|want|have|looking for).* (' + (knownTech.join '|') + ')', 'i');

  getProjects = (cb) ->
    robot.http('http://googledoctoapi.forberniesanders.com/1zKQZGGdKvDudZKKyds33vZMPwxt7I8soKt9qZ0t1LhE/')
    .header('User-Agent', 'Mozilla/5.0')
    .get() (err, res, body) ->
      if err
        msg.send 'I was unable to look up the projects'
        robot.emit 'error', err, res
        return

      projects = JSON.parse(body);
      projects = _.filter projects, (project) ->
        project.slack_name && project.project_type && project.slack_channel && project.used_tech
      .map (project) ->
        project =
          'name': project.project,
          'channel': robot.adapter.client.getChannelByName(project.slack_channel.replace('#', '').trim()),
          'leaders': project.slack_name.split(','),
          'tech': project.used_tech.toLowerCase(),
          'description': project.description,
          'type': project.project_type,
          'type_slug': _.snakeCase project.project_type
      .filter (project) ->
        return !!project.channel
      cb(projects)

  formatProjectMessage = (project) ->
    [
      '*' + project.name + '*',
      '(' + project.type + ')',
      'in <#' + project.channel.id + '>',
      'lead by ' + project.leaders.join ', '
    ].join ' '


  projectResponseHandler = (msg) ->
    skill = msg.match[1].toLowerCase()

    getProjects (projects) ->
      projects = projects.filter (project) ->
        (project.type_slug of projectTypes && _.contains projectTypes[project.type_slug], skill) || _.contains project.tech, skill

      if projects.length > 0
        message = ['We have found ' + projects.length + ' projects:']
        message.push _.map projects, formatProjectMessage
        msg.send _.flatten(message).join('\n')

  robot.respond /list projects/i, (msg) ->
    msg.send 'I\'ll PM you a list of the projects!'
    getProjects (projects) ->
      messages = _.map projects, formatProjectMessage
      messages.push('You can find all the projects at https://docs.google.com/spreadsheets/d/1zKQZGGdKvDudZKKyds33vZMPwxt7I8soKt9qZ0t1LhE');
      robot.send {room: msg.envelope.user.name}, messages.join '\n'

  robot.hear projectPattern, projectResponseHandler
  robot.respond projectPattern, projectResponseHandler
