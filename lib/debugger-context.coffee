StateMachine = require 'javascript-state-machine'
q = require 'q'
Client = require './client'

module.exports =
class DebuggerContext
  constructor: ->
    @client = new Client()
    @backtrace = []
    @locals = []
    @globals = []
    @state = StateMachine.create
      initial: 'disconnected'
      events: [
        { name: 'connect',    from: 'disconnected', to: 'connected' }
        { name: 'start',      from: 'connected',    to: 'running' }
        { name: 'pause',      from: 'running',      to: 'paused' }
        { name: 'continue',   from: 'paused',       to: 'running' }
        { name: 'disconnect', from: '*',            to: 'disconnected' }
      ]

    @client.onPaused (args...) => @paused(args...)
    @client.onDisconnected => @disconnected()

  isConnected: =>
    not @isDisconnected()

  isDisconnected: =>
    @state.is('disconnected')

  isRunning: ->
    @state.is('running')

  isPaused: =>
    @state.is('paused')

  connect: =>
    @client
      .connect()
      .then => @state.connect()
      .catch (e) ->
        # most probably "Error: connect ECONNREFUSED 127.0.0.1:1234" because rdebug-ide hasn't been started
        atom.notifications.addError e.toString(), dismissable: true

  disconnect: =>
    @client.disconnect()

  disconnected: ->
    @state.disconnect()

  pause: ->
    @client.pause()

  stepIn: ->
    @state.continue()
    @client.stepIn()

  stepOut: ->
    @state.continue()
    @client.stepOut()

  stepOver: ->
    @state.continue()
    @client.stepOver()

  # TODO: when to reset @backtrace etc to be empty? look at how Chrome debugger does it. maybe write some tests
  paused: (breakpoint) ->
    @state.pause()
    atom.workspace.open(breakpoint.file, initialLine: breakpoint.line - 1)

    q.all([
      @client.backtrace()
      @client.localVariables()
      @client.globalVariables()
    ])
    .then ([@backtrace, @locals, @globals]) => null
    .done()

  play: ->
    if @state.can('start')
      @client.start()
      @state.start()
    else
      @client.continue()
      @state.continue()

  destroy: ->
    @client.destroy()
