###
  This object is a simple json based serializer with advanced conviniences for
  managing CouchDB entities.

@namespace EmberCouchDBKit 
@class DocumentSerializer
@extends DS.RESTSerializer.extend
###
EmberCouchDBKit.DocumentSerializer = DS.RESTSerializer.extend

  primaryKey: 'id'


  normalize: (type, hash, prop) ->
    @normalizeId(hash)
    @normalizeUsingDeclaredMapping(type, hash)
    @normalizeAttributes(type, hash)
    @normalizeRelationships(type, hash)
    return @normalizeHash[prop](hash)  if @normalizeHash and @normalizeHash[prop]
    if (!hash)
      return hash

    this.applyTransforms(type, hash);
    hash;

  extractSingle: (store, type, payload, id, requestType) ->
    @_super(store, type, payload, id, requestType)

#  serializeAttribute: (record, json, key, attribute) ->
#    attrs = Ember.get(this, "attrs")
#    value = Ember.get(record, key)
#    type = attribute.type
#    if type && @transformFor(type)
#      transform = @transformFor(type)
#      value = transform.serialize(value)
#
#    # if provided, use the mapping provided by `attrs` in
#    # the serializer
#    key = attrs and attrs[key] or key
#    json[key] = value

#  extractHasMany: (type, hash, key) ->
#    if key == "attachments" || key == "_attachments"
#      @extractAttachments(hash["_attachments"],  type.toString(), hash)
#    else
#      hash[key]
#
#  extractBelongsTo: (type, hash, key) ->
#    if key == "history"
#      @extractId(type, hash) + "/history"
#    else
#      hash[key]
#
#  extract: (loader, json, type) ->
#    @extractRecordRepresentation(loader, type, json)
#
#  extractAttachments: (attachments, type, hash) ->
#    _attachments = []
#    for k, v of attachments
#      key = "#{hash._id}/#{k}"
#      attachment =
#        id: key
#        content_type: v.content_type
#        digest: v.digest
#        length: v.length
#        stub: v.stub
#        doc_id: hash._id
#        _rev: hash._rev
#        file_name: k
#        doc_type: type
#        revpos: v.revpos
#        db: v.db
#
#      EmberCouchDBKit.AttachmentStore.add(key, attachment)
#      _attachments.push(key)
#    _attachments
#
  normalizeId: (hash) ->
    unless hash[@get('primaryKey')]
      hash.id = hash["_id"]
      delete hash["_id"]

  normalizeRelationships: (type, hash) ->
    payloadKey = undefined
    key = undefined
    if @keyForRelationship
      type.eachRelationship ((key, relationship) ->
        payloadKey = @keyForRelationship(key, relationship.kind)
        return  if key is payloadKey
        hash[key] = hash[payloadKey]
      ), this

#  stringForType: (type) ->
#    type = type.toString()
#    if type.search(".") < 0
#      type
#    else
#      pattern = /((?:.*))\.(\w+)/ig
#      reg_array = pattern.exec(type)
#      reg_array[reg_array.length - 1].toString().toLowerCase()
#
#  getRecordRevision: (record) ->
#    record.get('_data._rev')
#
#  addId: (json, key, id) ->
#    json._id = id
#
#  addRevision: (json, record, options) ->
#    if options && options.includeId
#      rev = @getRecordRevision(record)
#      json._rev = rev if rev
#
#  addTypeAttribute: (json, record) ->
#    if @get('add_type_attribute')
#      typeAttribute = @get('typeAttribute')
#      json[typeAttribute] = @stringForType(record.constructor)
#
#  addHasMany: (data, record, key, relationship) ->
#    @_addHasMany(data, record, key, relationship)
#
#  _addHasMany: (data, record, key, relationship) ->
#    value = record.get(key)
#    attr_key = record.get("#{relationship.key}_key") || "id"
#    if @get('addEmptyHasMany') || !Ember.isEmpty(value)
#      values = value.getEach(attr_key)
#      if (values.every (value) -> !value) #find undefined in relations
#        values = record.get('_data.raw')[key]
#        data[key] = values if values
#      else
#        data[key] = values
#
#  addBelongsTo: (hash, record, key, relationship) ->
#    return if key == "history"
#    id_key = record.get("#{relationship.key}_key") || "id"
#    id = Ember.get(record, "#{relationship.key}.#{id_key}")
#    if Ember.isEmpty(id) && record.get('_data.raw')
#      hash[key] = record.get('_data.raw')[key] unless Ember.isEmpty(record.get('_data.raw')[key])
#    else
#      hash[key] = id if @get('addEmptyBelongsTo') || !Ember.isEmpty(id)

###

  An `DocumentAdapter` is a main adapter for connecting your models with CouchDB documents.

  Let's consider a simple model:

    ```
    EmberApp.CouchDBModel = DS.Model.extend
       title: DS.attr('title')

    EmberApp.Store.registerAdapter('EmberApp.CouchDBModel', EmberCouchDBKit.DocumentAdapter.extend({db: 'my_couchdb'}))
    ```

  The following available operations:

    ```
      # GET /my_couchdb/:id
      EmberApp.CouchDBModel.find("id")

      # POST /my_couchdb
      EmberApp.CouchDBModel.create({type: "my_type", title: "title"})

      # PUT /my_couchdb/:id
      model = EmberApp.CouchDBModel.find("id")
      model.set('title', 'new_title')
      model.get('store').commit()

      # DELETE /my_couchdb/:id
      model.deleteRecord()
    ```

  In additional, the following relations also available for getting and pushing related models:

    ```
    EmberApp.Post = DS.Model.extend
       type: DS.attr('string', defaultValue: 'post')
       title: DS.attr('string')

       # {"owner": "person@example.com"}
       owner:  DS.belongsTo('EmberApp.User', { key: 'owner': true})
       owner_key: 'email'

       # {"people":["person1@example.com", "person2@example.com"]}
       people: DS.hasMany('EmberApp.User',   { key: 'people', embedded: true})
       people_key: 'email'
    ```

  You can use `find` method for quering design views:

    ```
    tasks = EmberApp.Task.find({type: "view", designDoc: 'tasks', viewName: "by_assignee", options: 'include_docs=true&key="%@"'.fmt(@get('email'))})
    array = tasks.get('content')
    # => Array[EmberApp.Task,..]
    ```

  ## Tip and tricks

  Getting a raw document object

    ```
    doc = EmberApp.CouchDBModel.find('myId')
    raw_json = doc.get('_data.raw')
    # => Object {_id: "...", _rev: "...", …}

  Creating a named document

    ```
    myDoc = EmberApp.CouchDBModel.createRecord({id: 'myId'})
    # …
    myDoc = EmberApp.CouchDBModel.find('myId')
    # => Object {id: "myId", …}

  If you wonder about some document which could be missed in your db, then you could use a simple `is` convenience

    ```
    doc = EmberApp.CouchDBModel.find(myId)
    doc.get('store.adapter').is(200, {for: doc})
    # => true
    doc.get('store.adapter').is(404, {for: doc})
    # => undefined
    ```

  You're able to fetch a `HEAD` for your document

    ```
    doc = EmberApp.CouchDBModel.find(myId)
    doc.get('store.adapter').head(doc).getAllResponseHeaders()
    # => "Date: Sat, 31 Aug 2013 13:48:30 GMT
    #    Cache-Control: must-revalidate
    #    Server: CouchDB/1.3.1 (Erlang OTP/R15B03)
    #    Connection: keep-alive
    #    ..."
    ```


@namespace EmberCouchDBKit
@class DocumentAdapter
@extends DS.Adapter
###
EmberCouchDBKit.DocumentAdapter = DS.Adapter.extend

  typeAttribute: 'ember_type'
  typeViewName: 'by-ember-type'
  customTypeLookup: false


  is: (status, h) ->
    return true if @head(h.for).status == status

  head: (h) ->
    docId = if typeof h == "object" then h.get('id') else h
    @ajax(docId, 'HEAD', { async: false })


  ajax: (url, type, modelType, hash) ->
    @_ajax('/%@/%@'.fmt(@get('db'), url || ''), type, modelType, hash)

  _ajax: (url, type, modelType, hash={}) ->
    adapter = this
    return new Ember.RSVP.Promise((resolve, reject) ->
      if url.split("/").pop() == "" then url = url.substr(0, url.length - 1)
      hash.url = url
      hash.type = type
      hash.dataType = 'json'
      hash.contentType = 'application/json; charset=utf-8'


      hash.context = adapter

      if hash.data && type != 'GET'
        _data = hash.data
        hash.data = JSON.stringify(hash.data)

      if adapter.headers
        headers = adapter.headers
        hash.beforeSend = (xhr) ->
          forEach.call Ember.keys(headers), (key) ->
            xhr.setRequestHeader key, headers[key]

      unless hash.success
        hash.success = (json) ->
          _data = {} unless _data

          adapter._normalizeRevision(json)
          _modelJson = {}
          _modelJson[modelType] = $.extend(_data, json)

          Ember.run(null, resolve, _modelJson)

      hash.error = (jqXHR, textStatus, errorThrown) ->
        if (jqXHR)
          jqXHR.then = null
        Ember.run(null, reject, jqXHR)

      Ember.$.ajax(hash)
    )

  _normalizeRevision: (json) ->
    if json._rev
      json.rev = json._rev
      delete json._rev


  shouldCommit: (record, relationships) ->
    @_super.apply(arguments)

  stringForType: (type) ->
    @get('serializer').stringForType(type)

  find: (store, type, id) ->
    if @_checkForRevision(id)
      @findWithRev(store, type, id)
    else
      @ajax(id, 'GET', type.typeKey)

  findWithRev: (store, type, id) ->
    [_id, _rev] = id.split("/")[0..1]
    @ajax("%@?rev=%@".fmt(_id, _rev), 'GET')

  findManyWithRev:(store, type, ids) ->
    ids.forEach (id) =>
      @findWithRev(store, type, id)

  findMany: (store, type, ids) ->
    console.log 'x'

    if @_checkForRevision(ids[0])
      @findManyWithRev(store, type, ids)
    else
      data =
        include_docs: true
        keys: ids

      @ajax('_all_docs?include_docs=true', 'POST', {
        data: data
      })

  findQuery: (store, type, query, modelArray) ->
    if query.type == 'view'
      designDoc = (query.designDoc || @get('designDoc'))

      @ajax('_design/%@/_view/%@'.fmt(designDoc, query.viewName), 'GET', {
        context: this
        data: query.options

        success: (data) ->
          recordDef = {}
          recordDef[designDoc] = data.rows.getEach('doc')
          Ember.run(null, resolve, recordDef)
      })

  findAll: (store, type) ->
    designDoc = @get('designDoc')

    if @get('customTypeLookup') && @viewForType
      params = {}
      viewName = @viewForType(type, params)
      params.include_docs = true

      @ajax('_design/%@/_view/%@'.fmt(designDoc, viewName), 'GET', {
        data: params
        success: (data) ->
          Ember.run(null, resolve, data.rows.getEach('doc'))
      })
    else
      typeViewName = @get('typeViewName')
      typeString = @stringForType(type)
      data =
        include_docs: true
        key: '"' + typeString + '"'

      @ajax('_design/%@/_view/%@'.fmt(designDoc, typeViewName), 'GET', {
        data: data
        success: (data) ->
          Ember.run(null, resolve, data.rows.getEach('doc'))
      })

  createRecord: (store, type, record) ->
    json = store.serializerFor(type.typeKey).serialize(record);
    @_push(store, type, record, json)

  updateRecord: (store, type, record) ->
    json = @serialize(record, {associations: true, includeId: true })
    #    @_updateAttachmnets(record, json) if record.get('attachments')
    @_push(store, type, record, json)

  deleteRecord: (store, type, record) ->
    @ajax("%@?rev=%@".fmt(record.get('id'), record.get('_data._rev')), 'DELETE', {
    })

  _updateAttachmnets: (record, json) ->
    _attachments = {}

    record.get('attachments').forEach (item) ->
      attachment = EmberCouchDBKit.AttachmentStore.get(item.get('id'))
      _attachments[item.get('file_name')] =
        content_type: attachment.content_type
        digest: attachment.digest
        length: attachment.length
        stub:   attachment.stub
        revpos: attachment.revpos

    json._attachments = _attachments
    delete json.attachments

  _checkForRevision: (id) ->
    id?.split("/").length > 1
    id.split("/").length > 1

  _push: (store, type, record, json) ->
    id     = record.get('id') || ''
    method = if record.get('id') then 'PUT' else 'POST'

    if record.get('_data.rev')
      json._rev = record.get('_data.rev')

    @ajax(id, method, type.typeKey, {
      data: json
    })