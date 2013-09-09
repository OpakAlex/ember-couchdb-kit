/*
  This object is a simple json based serializer with advanced conviniences for
  extracting all document's attachment metadata and prepare them for further extracting.

@namespace EmberCouchDBKit
@class AttachmentSerializer
@extends DS.JSONSerializer
*/


(function() {
  EmberCouchDBKit.AttachmentSerializer = DS.RESTSerializer.extend({
    primaryKey: 'id',
    normalize: function(type, hash) {
      var rev, self;

      self = this;
      rev = hash._rev || hash.rev;
      this.store.find(hash.doc_type, hash.doc_id).then(function(document) {
        if (document.get('_data.rev') !== rev) {
          if (self.getIntRevision(document.get('_data.rev')) < self.getIntRevision(rev)) {
            return document.set('_data.rev', rev);
          }
        }
      });
      return this._super(type, hash);
    },
    getIntRevision: function(revision) {
      return parseInt(revision.split("-")[0]);
    },
    normalizeId: function(hash) {
      return hash.id = hash["_id"] || hash["id"];
    }
  });

  /*
    An `AttachmentAdapter` is an object which manages document's attachements and used
    as a main adapter for `Attachment` models.
  
    Let's consider an usual use case:
  
      ```
      App.Task = DS.Model.extend
        title: DS.attr('string')
        attachments: DS.hasMany('App.Attachment', {embedded: true})
  
      App.Store.registerAdapter('App.Task', EmberCouchDBKit.DocumentAdapter.extend({db: 'docs'}))
  
      App.Attachment = DS.Model.extend
        content_type: DS.attr('string')
        length: DS.attr('number')
        file_name: DS.attr('string')
        db: DS.attr('string')
  
      App.Store.registerAdapter('App.Attachment', EmberCouchDBKit.AttachmentAdapter.extend({db: 'docs'}))
      ```
  
    So, the `App.Task` model is able to load its attachments as many `App.Attachment` models.
  
      ```
      task = App.Task.find("3bbf4b8c504134dd125e7b603b004b71")
      attachemnts = task.attachments # as an Ember.Enumerable instance
      ```
  
    In short, there is a simple example how to commit `App.Attachment` record
  
      ```
      params = {
        doc_id: doc_id
        doc_type: doc_type
  
        id: attachment_id
        blob_data: blob_data
        rev: doc_rev
        content_type: file_type
        length: file_size
        file_name: name
      }
  
      attachment = TaskEmber.Attachment.createRecord(params)
      attachment.get('store').commit()
      ```
  
  @namespace EmberCouchDBKit
  @class AttachmentAdapter
  @extends DS.Adapter
  */


  EmberCouchDBKit.AttachmentAdapter = DS.Adapter.extend({
    find: function(store, type, id) {
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return Ember.run(null, resolve, {
          attachment: EmberCouchDBKit.AttachmentStore.get(id)
        });
      });
    },
    findMany: function(store, type, ids) {
      var docs,
        _this = this;

      docs = ids.map(function(item) {
        item = EmberCouchDBKit.AttachmentStore.get(item);
        item.db = _this.get('db');
        return item;
      });
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return Ember.run(null, resolve, {
          attachments: docs
        });
      });
    },
    createRecord: function(store, type, record) {
      var adapter, url;

      url = "%@/%@?rev=%@".fmt(this.buildURL(), record.get('id'), record.get('rev'));
      adapter = this;
      return new Ember.RSVP.Promise(function(resolve, reject) {
        var data, request,
          _this = this;

        data = {};
        data.context = adapter;
        request = new XMLHttpRequest();
        request.open('PUT', url, true);
        request.setRequestHeader('Content-Type', record.get('content_type'));
        adapter._updateUploadState(record, request);
        request.onreadystatechange = function() {
          var json;

          if (request.readyState === 4 && (request.status === 201 || request.status === 200)) {
            data = JSON.parse(request.response);
            data.doc_type = record.get('doc_type');
            data.doc_id = record.get('doc_id');
            json = adapter.serialize(record, {
              includeId: true
            });
            delete data.id;
            return Ember.run(null, resolve, {
              attachment: $.extend(json, data)
            });
          }
        };
        return request.send(record.get('file'));
      });
    },
    updateRecord: function(store, type, record) {},
    deleteRecord: function(store, type, record) {
      return new Ember.RSVP.Promise(function(resolve, reject) {
        return Ember.run(null, resolve, {});
      });
    },
    _updateUploadState: function(record, request) {
      var view,
        _this = this;

      view = record.get('view');
      if (view) {
        view.startUpload();
        return request.onprogress = function(oEvent) {
          var percentComplete;

          if (oEvent.lengthComputable) {
            percentComplete = (oEvent.loaded / oEvent.total) * 100;
            return view.updateUpload(percentComplete);
          }
        };
      }
    },
    buildURL: function() {
      var host, namespace, url;

      host = Ember.get(this, "host");
      namespace = Ember.get(this, "namespace");
      url = [];
      if (host) {
        url.push(host);
      }
      if (namespace) {
        url.push(namespace);
      }
      url.push(this.get('db'));
      url = url.join("/");
      if (!host) {
        url = "/" + url;
      }
      return url;
    }
  });

}).call(this);
