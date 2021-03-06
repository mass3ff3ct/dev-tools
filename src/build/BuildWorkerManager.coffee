{fork} = require('child_process')
Future = require('../utils/Future')


class BuildWorkerManager
  ###
  Build worker process representation on the main build process side.
  ###

  # maximum number of unacknowleged tasks after which the worker stops accepting new tasks
  @MAX_SENDING_TASKS = 50
  # number of milliseconds of idle state (without active tasks) after which the worker is auto-stopped
  @IDLE_STOP_TIMEOUT = 5000
  # worker id counter
  @_idCounter: 0
  # worker id (mostly for debugging purposes)
  id: 0
  # child process (in terms of nodejs)
  _process: null
  # Map[taskId, Future] of active task result futures to be able to notify build manager about task completion
  _tasks: null
  # how many tasks are sent to worker process but not acknowleged
  _sendingTask: 0
  # future that is resolved when this worker is ready to accept new tasks
  _acceptReady: null
  # current workload rate of the worker process
  _workload: 0
  # current number processing tasks
  _taskCounter: 0
  # counter of the tasks executed by this worker
  totalTasksCount: 0
  # timeout handle need to auto-stop the worker when idle
  _killTimeout: null
  _stopped: false

  constructor: (@manager) ->
    @id = ++BuildWorkerManager._idCounter
    # All child processes should be started without debug!
    childExecArgv = process.execArgv.filter (arg) -> -1 == arg.indexOf('--debug')
    @_process = fork(__dirname + '/build-worker.js', execArgv: childExecArgv)
    @_acceptReady = Future.resolved(this)
    @_tasks = {}
    # worker process communication callback
    @_process.on 'message', (m) =>
      switch m.type
        when 'completed'
          @_tasks[m.task].resolve()
        when 'failed'
          @_tasks[m.task].reject(m.error)
      delete @_tasks[m.task]
      @_taskCounter--
      if @_taskCounter == 0 and not @_stopped
        @_killTimeout = setTimeout =>
          @stop() if @_taskCounter == 0
        , BuildWorkerManager.IDLE_STOP_TIMEOUT

    @_process.on 'exit', (code, signal) ->
      console.log "Process 'exit' with params", code, signal if false

    @_process.on 'error', (err) ->
      console.log "Process 'error'", err

    @_process.on 'close', (code, signal) ->
      console.log "Process 'close' with params", code, signal if false


  addTask: (taskParams) ->
    ###
    @return Future<undefined>
    ###
    if @canAcceptTask()
      @_tasks[taskParams.id] = Future.single()
      @_process.send(taskParams)
      @_sendingTask++
      @_acceptReady = Future.single() if not @canAcceptTask()
      @_taskCounter++
      @totalTasksCount++
      clearTimeout(@_killTimeout) if @_killTimeout
      taskWorkload = @getTaskWorkload(taskParams)
      @_workload += taskWorkload
      @_tasks[taskParams.id].finally =>
        @_workload -= taskWorkload
        @_sendingTask--
        @_acceptReady.resolve(this)  if not @_acceptReady.completed() and @canAcceptTask()
    else
      e = new Error("Can't accept task now!")
      e.overwhelmed = true
      throw e


  getTaskWorkload: (taskParams) ->
    info = taskParams.info
    switch info.ext
      when '.coffee' then 1.2
      when '.styl' then 1.5
      when '.js' then 0.2
      when '.html'
        if info.isWidgetTemplate
          1
        else
          0
      else 0


  stop: ->
    ###
    Kills worker process and stops this worker.
    ###
    clearTimeout(@_killTimeout) if @_killTimeout
    if not @_stopped
      @_process.kill()
      @manager.stopWorker(this)
      @_stopped = true


  canAcceptTask: -> @_sendingTask < BuildWorkerManager.MAX_SENDING_TASKS


  acceptReady: -> @_acceptReady


  getWorkload: -> @_workload



module.exports = BuildWorkerManager
