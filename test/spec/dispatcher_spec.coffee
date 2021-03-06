define [
  'underscore'
  'chaplin/mediator'
  'chaplin/controllers/controller'
  'chaplin/dispatcher'
], (_, mediator, Controller, Dispatcher) ->
  'use strict'
  describe 'Dispatcher', ->
    #console.debug 'Dispatcher spec'

    # Initialize shared variables
    dispatcher = params = null

    # Unique ID counter for creating params objects
    paramsId = 0

    # Fake route objects, walk like a route and swim like a route

    route1 = controller: 'test1', action: 'show'
    route2 = controller: 'test2', action: 'show'

    redirectToURLRoute = controller: 'test1', action: 'redirectToURL'
    redirectToControllerRoute = controller: 'test1', action: 'redirectToController'

    # Reset helpers

    refreshParams = ->
      # Create a fresh params object which does not equal the previous one
      params = changeURL: false, id: paramsId++

    # Define test controllers
    class Test1Controller extends Controller

      historyURL: (params) ->
        #console.debug 'Test1Controller#historyURL'
        'test1/' + (params.id or '')

      initialize: (params, oldControllerName) ->
        #console.debug 'Test1Controller#initialize', params, oldControllerName
        super

      show: (params, oldControllerName) ->
        #console.debug 'Test1Controller#show', params, oldControllerName

      redirectToURL: (params, oldControllerName) ->
        @redirectTo '/test2/123'

      redirectToController: (params, oldControllerName) ->
        @redirectTo 'test2', 'show', params

      dispose: (params, newControllerName) ->
        #console.debug 'Test1Controller#dispose'
        super

    class Test2Controller extends Controller

      historyURL: (params) ->
        #console.debug 'Test2Controller#historyURL'
        'test2/' + (params.id or '')

      initialize: (params, oldControllerName) ->
        #console.debug 'Test2Controller#initialize', params, oldControllerName
        super

      show: (params, oldControllerName) ->
        #console.debug 'Test2Controller#show', params, oldControllerName

      dispose: (params, newControllerName) ->
        #console.debug 'Test2Controller#dispose'
        super

    # Define a test controller AMD modules
    define 'controllers/test1_controller', -> Test1Controller
    define 'controllers/test2_controller', -> Test2Controller

    beforeEach refreshParams

    it 'should initialize', ->
      dispatcher = new Dispatcher()

    it 'should dispatch routes to controller actions', ->
      proto = Test1Controller.prototype
      historyURL = sinon.spy(proto, 'historyURL')
      initialize = sinon.spy(proto, 'initialize')
      action     = sinon.spy(proto, 'show')

      mediator.publish 'matchRoute', route1, params

      expect(initialize).was.calledWith params, null
      expect(action).was.calledWith params, null
      expect(historyURL).was.calledWith params
      historyURL.restore()
      initialize.restore()
      action.restore()

    it 'should not start the same controller if params match', ->
      mediator.publish 'matchRoute', route1, params

      proto = Test1Controller.prototype
      historyURL = sinon.spy(proto, 'historyURL')
      initialize = sinon.spy(proto, 'initialize')
      action     = sinon.spy(proto, 'show')

      mediator.publish 'matchRoute', route1, params

      expect(initialize).was.notCalled()
      expect(action).was.notCalled()
      expect(historyURL).was.notCalled()
      historyURL.restore()
      initialize.restore()
      action.restore()

    it 'should start the same controller if params differ', ->
      mediator.publish 'matchRoute', route1, params

      proto = Test1Controller.prototype
      historyURL = sinon.spy(proto, 'historyURL')
      initialize = sinon.spy(proto, 'initialize')
      action     = sinon.spy(proto, 'show')

      refreshParams()
      mediator.publish 'matchRoute', route1, params

      expect(initialize).was.calledWith params, 'test1'
      expect(action).was.calledWith params, 'test1'
      expect(historyURL).was.calledWith params
      historyURL.restore()
      initialize.restore()
      action.restore()

    it 'should start the same controller if forced', ->
      mediator.publish 'matchRoute', route1, params

      proto = Test1Controller.prototype
      historyURL = sinon.spy(proto, 'historyURL')
      initialize = sinon.spy(proto, 'initialize')
      action     = sinon.spy(proto, 'show')

      params.forceStartup = true
      mediator.publish 'matchRoute', route1, params

      expect(initialize).was.calledWith params, 'test1'
      expect(action).was.calledWith params, 'test1'
      expect(historyURL).was.calledWith params
      historyURL.restore()
      initialize.restore()
      action.restore()

    it 'should save the controller, action, params and url', ->
      # Now route to Test2Controller
      mediator.publish 'matchRoute', route2, params

      d = dispatcher
      expect(d.previousControllerName).to.equal 'test1'
      expect(d.currentControllerName).to.equal 'test2'
      expect(d.currentController).to.be.a Test2Controller
      expect(d.currentAction).to.equal 'show'
      expect(d.currentParams).to.equal params
      expect(d.url).to.equal "test2/#{params.id}"

    it 'should dispose inactive controllers and fire beforeControllerDispose events', ->
      proto = Test2Controller.prototype
      dispose = sinon.spy(proto, 'dispose')

      # Route back to Test1Controller
      mediator.publish 'matchRoute', route1, params

      expect(dispose).was.calledWith params, 'test1'
      dispose.restore()

    it 'should fire beforeControllerDispose events', ->
      beforeControllerDispose = sinon.spy()
      mediator.subscribe 'beforeControllerDispose', beforeControllerDispose

      # Now route to Test2Controller
      mediator.publish 'matchRoute', route2, params

      expect(beforeControllerDispose).was.called()
      passedController = beforeControllerDispose.lastCall.args[0]
      expect(passedController).to.be.a Test1Controller
      expect(passedController.disposed).to.be.ok()

      mediator.unsubscribe 'beforeControllerDispose', beforeControllerDispose

    it 'should publish startupController events', ->
      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      # Route back to Test1Controller
      mediator.publish 'matchRoute', route1, params

      passedEvent = startupController.lastCall.args[0]
      expect(passedEvent).to.be.an 'object'
      expect(passedEvent.controller).to.be.a Test1Controller
      expect(passedEvent.controllerName).to.equal 'test1'
      expect(passedEvent.params).to.equal params
      expect(passedEvent.previousControllerName).to.equal 'test2'

      mediator.unsubscribe 'startupController', startupController

    it 'should listen to !startupController events', ->
      proto = Test1Controller.prototype
      historyURL = sinon.spy(proto, 'historyURL')
      initialize = sinon.spy(proto, 'initialize')
      action     = sinon.spy(proto, 'show')

      mediator.publish '!startupController', 'test1', 'show', params

      expect(initialize).was.calledWith params, 'test1'
      expect(action).was.calledWith params, 'test1'
      expect(historyURL).was.calledWith params

      d = dispatcher
      expect(d.previousControllerName).to.equal 'test1'
      expect(d.currentControllerName).to.equal 'test1'
      expect(d.currentController).to.be.a Test1Controller
      expect(d.currentAction).to.equal 'show'
      expect(d.currentParams).to.equal params
      expect(d.url).to.equal "test1/#{params.id}"
      historyURL.restore()
      initialize.restore()
      action.restore()

    it 'should support redirection to a URL', ->
      proto = Test1Controller.prototype
      action = sinon.spy(proto, 'redirectToURL')

      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      mediator.publish 'matchRoute', redirectToURLRoute, params

      expect(action).was.calledWith(params, 'test1')

      # Don’t expect that the new controller was called
      # because we’re not testing the router. Just test
      # if execution stopped (e.g. Test1Controller is still active)
      d = dispatcher
      expect(d.previousControllerName).to.equal 'test1'
      expect(d.currentControllerName).to.equal 'test1'
      expect(d.currentController).to.be.a Test1Controller
      expect(d.currentAction).to.equal 'show'
      expect(d.currentParams).not.to.equal params
      expect(d.url).not.to.equal "test1/#{params.id}"

      expect(startupController).was.notCalled()

      mediator.unsubscribe 'startupController', startupController
      action.restore()

    it 'should support redirection to a controller action', ->
      proto = Test1Controller.prototype
      redirectAction = sinon.spy(proto, 'redirectToController')

      proto = Test2Controller.prototype
      targetAction = sinon.spy(proto, 'show')

      startupController = sinon.spy()
      mediator.subscribe 'startupController', startupController

      # Redirects from Test1Controller to Test2Controller
      mediator.publish 'matchRoute', redirectToControllerRoute, params

      expect(redirectAction).was.calledWith params, 'test1'
      expect(targetAction).was.calledWith params, 'test1'

      # Expect that the new controller was called because this does not require
      # the router but the controller to fire a !startupController event
      d = dispatcher
      expect(d.previousControllerName).to.equal 'test1'
      expect(d.currentControllerName).to.equal 'test2'
      expect(d.currentController).to.be.a Test2Controller
      expect(d.currentAction).to.equal 'show'
      expect(d.currentParams).to.equal params
      expect(d.url).to.equal "test2/#{params.id}"

      # startupController event was only triggered once
      expect(startupController).was.called()
      expect(startupController.callCount).to.equal 1

      mediator.unsubscribe 'startupController', startupController
      redirectAction.restore()

    it 'should dispose itself correctly', ->
      expect(dispatcher.dispose).to.be.a 'function'
      dispatcher.dispose()

      proto = Test1Controller.prototype
      initialize = sinon.spy(proto, 'initialize')
      mediator.publish 'matchRoute', route1, params
      expect(initialize).was.notCalled()

      expect(dispatcher.disposed).to.be.ok()
      if Object.isFrozen
        expect(Object.isFrozen(dispatcher)).to.be.ok()
      initialize.restore()

    it 'should be extendable', ->
      expect(Dispatcher.extend).to.be.a 'function'

      DerivedDispatcher = Dispatcher.extend()
      derivedDispatcher = new DerivedDispatcher()
      expect(derivedDispatcher).to.be.a Dispatcher

      derivedDispatcher.dispose()
