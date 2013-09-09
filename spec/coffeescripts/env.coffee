class @DatabaseCleaner
  @reset: ->
    @destroy()
    @create()

  @create: ->
    @_ajax('PUT')

  @destroy: ->
    @_ajax('DELETE')

  @_ajax: (type) ->
    jQuery.ajax({
      url:  "/doc",
      type: type,
      dataType:    'json',
      contentType: "application/json"
      cache:       true,
      async: false
    })


class @TestEnv

  constructor: ->
    DatabaseCleaner.reset()

    unless window.Fixture

      @models()

      window.Fixture = window.setupStore({person: Person, comment: Comment, article: Article, message: Message, adapter: EmberCouchDBKit.DocumentAdapter.extend({
        db: 'doc'
      })})

    @


  models: ->
    window.Person = DS.Model.extend
      name: DS.attr('string')

#      history: DS.belongsTo('Fixture.History')


    window.Comment = DS.Model.extend
      text: DS.attr('string')

    window.Article = DS.Model.extend
      label: DS.attr('string')
      person: DS.belongsTo('person'),
      comments: DS.hasMany('comment', {async: true})

    window.Message = DS.Model.extend
      person: DS.belongsTo('person', {attribute: "name"}),

    History = DS.Model.extend()

#    Fixture.Store.registerAdapter('Fixture.History', EmberCouchDBKit.RevsAdapter.extend({db: 'doc'}))

  create: (type, params) ->

    model = window.Fixture.store.createRecord(type, params)


    runs ->
      model.save()

    waitsFor ->
      model.get('_data.rev')
    , "Article id should have NOT be null", 3000

    model


window.setupStore = (options) ->
  env = {}
  options = options or {}
  container = env.container = new Ember.Container()
  adapter = env.adapter = (options.adapter or DS.Adapter)
  delete options.adapter

  for prop of options
    container.register "model:" + prop, options[prop]
  container.register "store:main", DS.Store.extend(adapter: adapter)
  container.register "serializer:_default", EmberCouchDBKit.DocumentSerializer
  container.register "serializer:_couch", EmberCouchDBKit.DocumentSerializer
  container.register "serializer:_rest", DS.RESTSerializer
  container.register "adapter:_rest", DS.RESTAdapter
  container.register('transform:boolean', DS.BooleanTransform)
  container.register('transform:date', DS.DateTransform)
  container.register('transform:number', DS.NumberTransform)
  container.register('transform:string', DS.StringTransform)
  container.injection "serializer", "store", "store:main"
  env.serializer = container.lookup("serializer:_default")
  env.restSerializer = container.lookup("serializer:_rest")
  env.store = container.lookup("store:main")
  env.adapter = env.store.get("defaultAdapter")
  env