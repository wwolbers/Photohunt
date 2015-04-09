Timer = require 'timer'
Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'

exports.onInstall = () !->
	newHunt(3) # we'll start with 3 subjects
	Event.create
		unit: 'hunts'
		text: "New Photo Hunt: earn points by completing the various hunts!"

exports.onUpgrade = !->
	# apparently a timer did not fire, correct it
	if 0 < Db.shared.get('next') < Plugin.time()
		newHunt()

exports.client_newHunt = exports.newHunt = newHunt = (amount = 1, cb = false) !->
	return if Db.shared.get('next') is -1
		# used to disable my plugins and master instances

	log 'newHunt called, amount '+amount
	hunts = [
"With Merel Hendrikx"
"With a Hotelbell"
"In the Ikea"
"With 2 empty toiletrolls before your eyes"
"With a hockeystick"
"On a roundabout"
"With a (real) celebrity"
"Under a bridge"
"In a taxi"
"With a cassette"
"With a paper dictionary"
"Lying on a sports field"
"In a dressing room"
"In the kitchen"
"Waving the Belgium flag"
"In a tree"
"With a KFC Bucket on your head"
"Drinking beer with a straw"
"Wearing a tie"
"Wearing a paper folded hat"
"With someone taller then you"
"With a real pig"
"Waving the Dutch flag"
"With a DVD"
"With the traffic behind you"
"In a soccer stadium"
"Playing with K’nex"
"Under the stairs"
"With a (real) hooker"
"In a lamp post of a sports field"
"Eating chicken"
"Baking cookies"
"With a family member"
"With one or more fishes"
"With a painting"
"With a drawing of yourself"
"In a groceries store"
"Wearing 3 watches"
"In a high school"
"With a washing machine"
"And a municipality employee"
"With an antique clock"
"With a printed face of Zlatan Ibrahimovic on your face"
"With a dog"
"With a cow"
"With a bird"
"Wearing a dog or cat collar"
"With (Holland)Casino coins"
"On the Eifel tower"
"In a restaurant"
"With an ice cube"
"Eating hot peppers"
"Dressed as a celebrity"
"With 56 euros"
"With dog or cat poo"
"On a bus"
"With an paper bag on your head"
"With a Nokia phone"
"Wearing 3D goggles"
"Licking a window"
"With a team member"
"In a dug out"
"With a fountain"
"With a Volkswagen Golf"
"With a brick"
"Eating dog or catfood"
"In a rubberboat"
"Smoking a joint"
"With a picture of Justin Bieber"
"On a airfield"
"In a carbrio"
"With a gun"
"Eating Swedish meatballs"
"In a closet"
"On a surfboard"
"Drinking liquor"
"With something from Apple"
"With a baseball bat"
"With something from Android"
"On a fence"
"In a (trash)container"
"With Wies van Achterberg"

	]

	# remove hunts that have taken place already
	if prevHunts = Db.shared.get('hunts')
		for huntId, hunt of prevHunts
			continue if !+huntId
			if (pos = hunts.indexOf(hunt.subject)) >= 0
				hunts.splice pos, 1

	# find some new hunts
	newHunts = []
	while amount-- and hunts.length
		sel = Math.floor(Math.random()*hunts.length)
		newHunts.push hunts[sel]
		hunts.splice sel, 1

	if !newHunts.length
		log 'no more hunts available'
		if cb
			cb.reply true
	else
		log 'selected new hunts: '+JSON.stringify(newHunts)

		for newHunt in newHunts
			maxId = Db.shared.ref('hunts').incr 'maxId'
				# first referencing hunts, as Db.shared.incr 'hunts', 'maxId' is buggy
			Db.shared.set 'hunts', maxId,
				subject: newHunt
				time: 0|(Date.now()*.001)
				photos: {}

			# schedule the next hunt when there are still hunts left
			if hunts.length
				tomorrowStart = Math.floor(Plugin.time()/86400)*86400 + 86400
				nextTime = tomorrowStart + (10*3600) + Math.floor(Math.random()*(12*3600))
				Timer.cancel()
				Timer.set (nextTime-Plugin.time())*1000, 'newHunt'
				Db.shared.set 'next', nextTime

		# we'll only notify when this is about a single new hunt
		if newHunts.length is 1
			subj = newHunts[0]
			Event.create
				unit: 'hunts'
				text: "New Photo Hunt: take a photo of you.. " + subj.charAt(0).toLowerCase() + subj.slice(1)

exports.client_removePhoto = (huntId, photoId, disqualify = false) !->
	photos = Db.shared.ref 'hunts', huntId, 'photos'
	return if !photos.get photoId

	thisUserSubmission = Plugin.userId() is photos.get(photoId, 'userId')
	name = Plugin.userName(photos.get photoId, 'userId')
	possessive = if name.charAt(name.length-1).toLowerCase() is 's' then "'" else "'s"

	if disqualify
		photos.set photoId, 'disqualified', true
	else
		photos.remove photoId

	# find a new winner if necessary
	newWinnerName = null
	if Db.shared.get('hunts', huntId, 'winner') is photoId
		smId = (+k for k, v of photos.get() when !v.disqualified)?.sort()[0]
		Db.shared.set 'hunts', huntId, 'winner', smId
		if smId
			newWinnerName = Plugin.userName(photos.get smId, 'userId')
			Event.create
				unit: 'hunts'
				text: "Photo Hunt: results revised, "+newWinnerName+" won! ("+Db.shared.get('hunts', huntId, 'subject')+")"

	comment = null
	if disqualify
		comment = "disqualified " + name + possessive + " submission"
	else if thisUserSubmission
		comment = "retracted submission"
	else if !thisUserSubmission
		comment = "removed " + name + possessive + " submission"

	if comment
		if newWinnerName
			comment = comment + ", making " + newWinnerName + " the new winner!"
		addComment huntId, comment


exports.onPhoto = (info, huntId) !->
	huntId = huntId[0]
	log 'got photo', JSON.stringify(info), Plugin.userId()

	# test whether the user hasn't uploaded a photo in this hunt yet
	allPhotos = Db.shared.get 'hunts', huntId, 'photos'
	for k, v of allPhotos
		if +v.userId is Plugin.userId()
			log "user #{Plugin.userId()} already submitted a photo for hunt "+huntId
			return

	hunt = Db.shared.ref 'hunts', huntId
	maxId = hunt.incr 'photos', 'maxId'
	hunt.set 'photos', maxId, info
	if !hunt.get 'winner'
		hunt.set 'winner', maxId
		Event.create
			unit: 'hunts'
			text: "Photo Hunt: "+Plugin.userName()+" won! ("+hunt.get('subject')+")"
	else
		addComment huntId, "added a runner-up"

addComment = (huntId, comment) !->
	comment =
		t: 0|Plugin.time()
		u: Plugin.userId()
		s: true
		c: comment

	comments = Db.shared.createRef("comments", huntId)
	max = comments.incr 'max'
	comments.set max, comment
