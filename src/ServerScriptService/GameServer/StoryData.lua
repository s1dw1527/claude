-- STORY DATA: the six chapters of Corner Empire's story mode, the rival's dialogue and every joke.
-- Edit freely: names, lines, objectives and rewards all live here. The rules that run it are in "Story".
--
-- Objectives (kind = ...), all checked by the server against the player's real progress:
--   served / earned / deliveries / contributed / followers  : lifetime totals (spending never undoes them)
--   level n   : any business at Level n          biz n   : n businesses open      staff n : n people hired
--   tier n    : reputation tier n or higher      combo n : n business combos      score n : Empire Score n
--   viral     : went viral at least once         luxury  : a Hyper Car, Golden Supercar, Hillside or Millionaire Row home
--   fives n   : n five-star reviews during this chapter
--   clapback / challenge / inspection / choice / finale : story moments (see Story)
-- after = true : the objective only opens once every other objective in the chapter is done
return function(C)
local RGB = Color3.fromRGB

-- the rival: an ORIGINAL streamer-style parody character (not any real person). Rename him here.
C.STORY_RIVAL = {name = "Lil Clipz", handle = "@ClipzLIVE", icon = "🎙️", color = RGB(255, 70, 140)}
C.STORY_CAST = {
	rival = {name = "Lil Clipz", icon = "🎙️", color = RGB(255, 70, 140)},
	kevin = {name = "Knockoff Kevin", icon = "🥤", color = RGB(255, 200, 60)},
	ulysses = {name = "Undercut Ulysses", icon = "🏷️", color = RGB(120, 200, 255)},
	brenda = {name = "Brenda Bottomline", icon = "📊", color = RGB(170, 120, 255)},
	reginald = {name = "Sir Reginald Moneybags IV", icon = "🎩", color = RGB(255, 205, 80)},
	gazette = {name = "Corner Gazette", icon = "📰", color = RGB(230, 230, 230)},
	narrator = {name = "", icon = "🎬", color = RGB(200, 200, 220)},
	you = {name = "You", icon = "😎", color = RGB(120, 230, 150)},
}

-- anim: entrance, point, laugh, clap, shrug, shock, kneel, hype (the client turns these into tweens)
-- stage: what the cutscene shows (plot = your businesses, limo = a golden limo arrives, spotlight = big entrance)
C.STORY = {
	{
		key = "broke", title = "BROKE LEGEND", icon = "🍋", stage = "plot",
		dm = "Yo. I'm watching your 'business' on stream right now. Chat says you're cooked. Prove them wrong. 🍋",
		blurb = "You, a folding table, and a dream. A loud streamer thinks this is hilarious.",
		intro = {
			{"rival", "YO CHAT, WE'RE LIVE! Today we're visiting the BROKEST business owner in the whole city!", "entrance"},
			{"rival", "BRO. YOUR ENTIRE EMPIRE IS A FOLDING TABLE! 💀", "point"},
			{"rival", "You call that a business? I've seen a vending machine with better management!", "laugh"},
			{"rival", "Your net worth is three dollars and a half-eaten sandwich. Chat, put some respect on the sandwich.", "laugh"},
			{"rival", "LOCK IN. This lemonade stand is NOT paying for your private jet. Prove me wrong. I'll be watching. 👀", "point"},
		},
		objectives = {
			{kind = "served", n = 60, text = "Serve 60 customers"},
			{kind = "earned", n = 5000, text = "Earn $5,000 of real profit"},
			{kind = "level", n = 3, text = "Upgrade a business to Level 3"},
			{kind = "clapback", after = true, text = "Prove Lil Clipz wrong: roast him back"},
		},
		clapbacks = {
			"Your stream has 4 viewers and 3 of them are your mom on different devices.",
			"I'll be a billionaire before your ring light is paid off.",
			"Keep talking. Every word is free advertising for my lemonade.",
		},
		outro = {
			{"rival", "...Okay. OKAY. The stand actually made money. Chat, do NOT clip that.", "shock"},
			{"rival", "I'm not saying it's a business. I'm saying it's... business-SHAPED. 🍋", "shrug"},
			{"narrator", "CHAPTER 1 COMPLETE • Lil Clipz reluctantly admits this might work."},
		},
		reward = {floor = 750, seconds = 60, title = "Broke Legend"},
	},
	{
		key = "pocket", title = "POCKET CHANGE CEO", icon = "🪙", stage = "plot",
		dm = "Heard you're about to hire someone. Don't embarrass yourself. And pay them in more than lemonade.",
		blurb = "A small business that actually works. Time to hire people and act like a boss.",
		intro = {
			{"rival", "Congratulations. You can ALMOST afford lunch! 🥪", "clap"},
			{"rival", "Your accountant is a calculator with a cracked screen.", "laugh"},
			{"rival", "Real CEOs have EMPLOYEES. You have a stand and a dream. Mostly the dream.", "point"},
			{"narrator", "Earn a good reputation, hire your first employee and open a third business."},
		},
		objectives = {
			{kind = "tier", n = 2, text = "Reach LOCAL FAVORITE reputation"},
			{kind = "staff", n = 1, text = "Hire your first employee"},
			{kind = "biz", n = 3, text = "Open 3 businesses"},
			{kind = "earned", n = 25000, text = "Earn $25,000 in total"},
		},
		outro = {
			{"rival", "You hired ONE employee and now you think you're a CEO?", "point"},
			{"rival", "...They ARE wearing a name tag though. That's lowkey corporate. 😤", "shrug"},
			{"narrator", "CHAPTER 2 COMPLETE • Pocket Change CEO"},
		},
		reward = {floor = 3000, seconds = 120},
	},
	{
		key = "menace", title = "LOCAL MENACE", icon = "😈", stage = "plot", copycat = true,
		dm = "Yo. I heard you're opening another location. Don't embarrass yourself. Also my cousin Kevin says hi. And 'I'm coming for you.'",
		blurb = "The neighborhood knows your name. So does Lil Clipz's cousin, who is copying you.",
		intro = {
			{"gazette", "📰 CORNER GAZETTE: \"LOCAL ENTREPRENEUR OPENS THREE BUSINESSES. STILL PARKS LIKE A BOT.\""},
			{"rival", "Chat, people are RECOGNIZING them now. That's MY job. I'm the famous one.", "shock"},
			{"kevin", "Hi! I opened a stand RIGHT across the street. It's called Lemon-AID. With an A-I-D. Totally different."},
			{"rival", "That's my cousin Kevin. He's copying you. Out-sell him and I'll... think about respecting you.", "laugh"},
		},
		objectives = {
			{kind = "biz", n = 4, text = "Open 4 businesses"},
			{kind = "combo", n = 1, text = "Unlock a business combo"},
			{kind = "tier", n = 3, text = "Reach HOTSPOT reputation"},
			{kind = "earned", n = 500000, text = "Earn $500,000 in total"},
			{kind = "challenge", after = true, text = "Out-sell Knockoff Kevin's copycat stand"},
		},
		challenge = {seconds = 300, incomeSeconds = 330, floor = 3000},
		outro = {
			{"kevin", "My stand made $14 and a raccoon stole all the cups. I'm going back to school."},
			{"rival", "You BANKRUPTED my cousin?! ...That's actually cold. Respect. A little. Like 4%.", "shock"},
			{"narrator", "CHAPTER 3 COMPLETE • Local Menace"},
		},
		reward = {floor = 25000, seconds = 120, rep = 25, title = "Local Menace"},
	},
	{
		key = "money", title = "ACTUALLY GETTING MONEY", icon = "💵", stage = "plot", inspection = true,
		dm = "A health inspector asked me where your shop is. I MAY have told him. Good luck. 😇",
		blurb = "A real business operation, a rival who undercuts everything, and an inspector with a clipboard.",
		intro = {
			{"rival", "Okay so you're ACTUALLY getting money now. I hate this. I hate it here.", "shrug"},
			{"ulysses", "Greetings. I've opened DISCOUNT EVERYTHING next door. Everything is one cent cheaper than you. Forever."},
			{"rival", "You finally have employees. Unfortunately, they have discovered the concept of weekends.", "laugh"},
			{"narrator", "A surprise inspection is on its way. Keep things clean, keep customers happy, and make a BIG move."},
		},
		objectives = {
			{kind = "earned", n = 5000000, text = "Earn $5,000,000 in total"},
			{kind = "inspection", text = "Pass the surprise inspection"},
			{kind = "fives", n = 10, text = "Get 10 five-star reviews (beat Ulysses' discounts)"},
			{kind = "deliveries", n = 3, text = "Complete 3 deliveries"},
			{kind = "choice", text = "Make your big move"},
		},
		choices = {
			{key = "reinvest", label = "📈 Reinvest", text = "Get any business to Level 8", kind = "level", n = 8},
			{key = "manager", label = "💼 Hire management", text = "Hire a Manager", kind = "role", role = "manager"},
			{key = "expand", label = "📍 Expand", text = "Open 5 businesses or buy district land", kind = "expand"},
		},
		outro = {
			{"ulysses", "Your customers... they LIKE you. That's not on my spreadsheet. I'm closing. Tell no one."},
			{"rival", "Chat... we might have to start calling them 'boss'. JK. Unless? 😳", "shock"},
			{"narrator", "CHAPTER 4 COMPLETE • Actually Getting Money"},
		},
		reward = {floor = 200000, seconds = 150},
	},
	{
		key = "famous", title = "THE CITY KNOWS YOUR NAME", icon = "🌆", stage = "spotlight",
		dm = "Bestie!!! I've been telling everyone we're best friends since day one. Please don't fact-check that.",
		blurb = "Fans, rival executives with ridiculous egos, and a citywide showdown.",
		intro = {
			{"rival", "LADIES AND GENTLEMEN... my BEST FRIEND. My BROTHER. I ALWAYS believed in this one!", "hype"},
			{"narrator", "(He did not.)"},
			{"brenda", "Brenda Bottomline, CEO of Synergy Synergy Inc. Let's circle back to you losing."},
			{"reginald", "My family has been rich for eleven generations. You have been rich for eleven minutes."},
			{"narrator", "The city's executives want an Executive Showdown. Prove your empire is the real deal."},
		},
		objectives = {
			{kind = "tier", n = 4, text = "Reach CITY ICON reputation"},
			{kind = "earned", n = 100000000, text = "Earn $100,000,000 in total"},
			{kind = "followers", n = 2500, text = "Reach 2,500 CityBuzz followers"},
			{kind = "contributed", n = 1000000, text = "Invest $1,000,000 in the Empire Spire"},
			{kind = "score", n = 75, text = "Win the Executive Showdown (Empire Score 75)"},
		},
		outro = {
			{"reginald", "Fine. FINE. Take the Executive Cup. I have twelve more at home."},
			{"brenda", "Let's take this offline. Forever. I'm moving to another city."},
			{"rival", "That's MY friend!! I DISCOVERED them!! Clip it, clip it, CLIP IT! 🎬", "hype"},
			{"narrator", "CHAPTER 5 COMPLETE • The City Knows Your Name"},
		},
		reward = {floor = 5000000, seconds = 180, title = "City Icon"},
	},
	{
		key = "billionaire", title = "BILLIONAIRE BEHAVIOR", icon = "💎", stage = "limo",
		dm = "So... about that small loan of a million dollars. Hypothetically. For content.",
		blurb = "Golden limos, paparazzi, a final showdown, and one very nervous streamer.",
		intro = {
			{"narrator", "A golden limo pulls up. The paparazzi go absolutely feral. 📸📸📸"},
			{"rival", "Can I borrow a small loan of one million dollars? For... content.", "kneel"},
			{"rival", "Your empire is worth billions, but you still can't find the parking entrance.", "laugh"},
			{"narrator", "One thing stands between you and legend status: Lil Clipz wants a FINAL SHOWDOWN."},
		},
		objectives = {
			{kind = "earned", n = 1000000000, text = "Earn $1,000,000,000 in total"},
			{kind = "tier", n = 5, text = "Reach EMPIRE reputation"},
			{kind = "luxury", text = "Flex: a Hyper Car, or a home on Hillside or Millionaire Row"},
			{kind = "finale", after = true, text = "Face Lil Clipz in the final showdown"},
		},
		finale = {
			{"rival", "I NEVER DOUBTED YOU!", "kneel"},
			{"narrator", "⏪ FLASHBACK...", nil, true},
			{"rival", "BRO. YOUR ENTIRE EMPIRE IS A FOLDING TABLE! 💀", "laugh", true},
			{"rival", "This lemonade stand is NOT paying for your private jet!", "point", true},
			{"narrator", "⏩ ...back to now."},
			{"rival", "Okay, that clip is going viral against me. Chat, delete that. DELETE THAT.", "shock"},
			{"rival", "Fine. You win. Here's the Golden Mic. 🎙️✨ Don't drop it. It's literally rented.", "clap"},
		},
		outro = {
			{"narrator", "CHAPTER 6 COMPLETE • You built an empire from a folding table."},
			{"rival", "So... rebirth? Season 2? Another era? I need CONTENT. Please. I'm begging. 🙏", "kneel"},
		},
		reward = {floor = 50000000, seconds = 300, title = "Billionaire", trophies = 1},
	},
}

-- what fans shout when they walk up to your businesses (from chapter 3 on)
C.STORY_SHOUTS = {
	[3] = {"Yo, it's the Local Menace!", "My cousin says your lemonade is illegal levels of good", "Are you the one who bankrupted Kevin?", "Can I get a selfie? For my mom."},
	[4] = {"Heard you're ACTUALLY getting money now", "Discount Everything is closed, let's gooo", "Is the inspector still crying?", "Saw you on the Gazette!"},
	[5] = {"OMG IT'S THEM!!!", "Can you sign my receipt?!", "Lil Clipz said you're his best friend??", "I named my goldfish after your empire"},
	[6] = {"THE BILLIONAIRE!!!", "Please adopt me", "Is that a gold limo or am I dreaming", "Where do you even park??", "Can I borrow a million dollars? Asking for Lil Clipz"},
	[7] = {"LEGEND!!!", "Season 2 when??", "My dad says you were a folding table once", "Golden Mic!! 🎙️"},
}
-- what your own employees mutter at work (from chapter 3 on)
C.STORY_STAFF_LINES = {
	[3] = {"Boss is a local legend. That makes me... a local legend's employee.", "A kid asked for my autograph. I signed 'Employee'."},
	[4] = {"Is it the weekend yet? It feels like the weekend.", "I saw the inspector. I hid in the freezer. Worth it.", "Ulysses offered me a job. I said no. He offered one cent more."},
	[5] = {"My mom saw us on CityBuzz!", "Fans keep asking if I'm the boss. I say 'kind of'."},
	[6] = {"Boss bought a limo. I got a new name tag. Basically the same thing.", "Do billionaires need someone to hold their lemonade?"},
	[7] = {"Working for a legend hits different.", "I tell people I knew the boss when it was a folding table."},
}
-- Corner Gazette headlines in CityBuzz (%s = the player's name)
C.STORY_HEADLINES = {
	[2] = {"%s hires first employee. Employee already asking about weekends.", "Local stand owner %s spotted saying 'synergy' unironically."},
	[3] = {"LOCAL ENTREPRENEUR %s OPENS THREE BUSINESSES. STILL PARKS LIKE A BOT.", "Copycat stand 'Lemon-AID' opens across from %s. Lawyers confused."},
	[4] = {"%s's empire passes surprise inspection. Inspector 'emotionally shaken'.", "DISCOUNT EVERYTHING closes after losing price war to %s."},
	[5] = {"%s named most talked-about tycoon. Lil Clipz claims he 'discovered' them.", "Executives demand rematch against %s. Request denied."},
	[6] = {"BILLIONAIRE %s STILL CAN'T FIND THE PARKING ENTRANCE.", "%s's golden limo blocks traffic for 3 hours. Fans: 'worth it'."},
}
-- the rival's commentary while you play (short speech bubbles, a few minutes apart at most)
C.STORY_ROASTS = {
	broke = {"BRO, YOUR ENTIRE EMPIRE IS A FOLDING TABLE!", "Your wallet just made a dial-up noise.", "I've seen more money in a couch cushion.", "Are you running a business or a charity for yourself?"},
	problemIgnored = {"You IGNORED a broken machine? Bold strategy.", "Problem? What problem? *business catches fire*", "Chat, they really said 'it'll fix itself'. 💀"},
	newBusiness = {"A new business?! Who's paying for this, the tooth fairy?", "Another one?? Okay, Mr. Monopoly.", "Wait, that's actually a good spot. I'm not saying anything."},
	viral = {"WAIT. The chat is going CRAZY for you right now. I'm not impressed. (I'm a little impressed.)", "You went viral before ME?! This is a scam."},
	luxury = {"You bought THAT but you still drive like a shopping cart.", "Nice ride. Did it come with driving lessons?"},
	rebirth = {"You gave it ALL up?! ...For a permanent bonus? Okay, that's actually smart. I hate it.", "Starting over? Chat, it's folding table season again! 💀"},
	challengeFail = {"KEVIN BEAT YOU?! Kevin can't spell lemonade!", "My cousin is out-selling you. Let that sink in."},
	idle = {
		[1] = {"Still at the stand? Chat, they're RUNNING a lemonade stand. Running it into the ground.", "Fun fact: your sandwich is worth more than your company."},
		[2] = {"Your 'staff meeting' is just you talking to a cash register.", "Pocket change CEO, reporting live from the couch."},
		[3] = {"Kevin's stand has a TikTok. Do you have a TikTok?", "The neighbors know your name. Mostly because of the parking."},
		[4] = {"Ulysses just cut his prices AGAIN. Respond. RESPOND.", "Your employees are on break. Again. Forever."},
		[5] = {"I told everyone we're best friends. Please don't fact-check that.", "Can I be in your next commercial? I'll do it for $1. Or $1,000,000."},
		[6] = {"I'm not jealous. I'm just... emotionally renting a mansion.", "When you're done being a billionaire can you teach me?"},
		[7] = {"Legend status and you're STILL here? Okay, I respect the grind.", "Season 2 idea: you, me, a podcast. Think about it."},
	},
	-- rare lines (about 1 in 25): little surprises so he doesn't feel scripted
	rare = {
		"Chat, I just realized I've never actually tasted the lemonade. ...Is it good? Don't answer that.",
		"Breaking: Lil Clipz's ring light has been repossessed. More at 11.",
		"I'm calling my lawyer. My lawyer is Kevin. We're doomed.",
		"Sometimes I watch your empire grow and I feel... things. Gross.",
		"If you ever need a mascot I own a lemon costume. For reasons.",
	},
}
end
