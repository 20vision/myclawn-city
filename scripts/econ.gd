extends Node
## The clone economy. Pure logic and save data, no visuals, so it can be tested headless.
## Chain: scout clones find leads -> closer clones turn 5 leads into a deal -> deals pay cash.
## Fund: cash becomes startup stakes that mature in real time, with power-law returns.

signal changed
signal toast(text: String)

const SAVE_PATH := "user://city_save.json"
const OFFLINE_CAP_S := 10.0 * 3600.0
const STAKE_TERM_S := 8.0 * 3600.0
const LEADS_PER_DEAL := 5.0
const SCOUT_LEADS_S := 1.0
const CLOSER_DEALS_S := 0.2
const DEAL_VALUE := 40.0
const LEAD_CAP_BASE := 100.0
const RANKS := [
	[0.0, "Solo Founder"], [1000.0, "Operator"], [10000.0, "Clone Boss"], [100000.0, "City Mogul"],
	[1000000.0, "Venture King"], [25000000.0, "Empire Builder"], [1000000000.0, "God of Clones"],
]
## Every fact here must stay true of the real product. See the live site before editing.
const FACTS := [
	"MyClawn is real. Outside this game it gives an AI agent its own cloud computer.",
	"A real MyClawn agent can browse the web on its own computer.",
	"A real MyClawn agent can write and send email.",
	"You watch a real MyClawn agent work live, and you can take over anytime.",
	"Signing up for the real MyClawn is free, with no install.",
	"This city's money is pretend. The real MyClawn is at myclawn.com.",
]

var s := {}
var now_override := -1.0  ## tests only


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	var t := Timer.new()
	t.wait_time = 15.0
	t.autostart = true
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	t.timeout.connect(save_game)
	add_child(t)


func now() -> float:
	return now_override if now_override >= 0.0 else Time.get_unix_time_from_system()


func fresh() -> Dictionary:
	return {
		"cash": 150.0, "earned": 0.0, "leads": 0.0, "scouts": 0, "closers": 0, "training": 0,
		"stakes": [], "funds": 1, "last_seen": now(), "streak": 0, "last_day": "", "claimed_day": "",
		"found": [], "jobs_done": 0, "job_chain": 0, "best_exit": 0.0, "away_report": 0.0,
	}


func load_game() -> void:
	s = fresh()
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			s.merge(data, true)
			s.scouts = int(s.scouts); s.closers = int(s.closers); s.training = int(s.training)
			s.funds = int(s.funds); s.streak = int(s.streak); s.jobs_done = int(s.jobs_done)
			s.job_chain = int(s.job_chain)
	apply_offline()


func save_game() -> void:
	if now_override >= 0.0:
		return  # tests must never touch a real save
	s.last_seen = now()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))
		f.close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not s.is_empty():
			save_game()


func mult() -> float:
	return pow(1.5, s.training)


func deals_per_s() -> float:
	return minf(s.closers * CLOSER_DEALS_S, s.scouts * SCOUT_LEADS_S / LEADS_PER_DEAL)


func income_per_s() -> float:
	return deals_per_s() * DEAL_VALUE * mult()


func lead_cap() -> float:
	return LEAD_CAP_BASE + s.scouts * 20.0


func _earn(amount: float) -> void:
	s.cash += amount
	s.earned += amount


func tick(dt: float) -> void:
	# Leads pile up in storage, so a shortage of closers is visible as a full bar.
	var produced: float = s.scouts * SCOUT_LEADS_S * dt
	s.leads = minf(s.leads + produced, lead_cap())
	var can_close: float = s.closers * CLOSER_DEALS_S * dt
	var deals: float = minf(can_close, s.leads / LEADS_PER_DEAL)
	s.leads -= deals * LEADS_PER_DEAL
	_earn(deals * DEAL_VALUE * mult())


func _process(delta: float) -> void:
	tick(delta)


func apply_offline() -> void:
	var away := clampf(now() - float(s.last_seen), 0.0, OFFLINE_CAP_S)
	var earned := income_per_s() * away
	_earn(earned)
	s.away_report = earned
	s.last_seen = now()


func take_away_report() -> float:
	var r: float = s.away_report
	s.away_report = 0.0
	return r


func clone_cost(kind: String) -> float:
	return (50.0 * pow(1.15, s.scouts)) if kind == "scout" else (100.0 * pow(1.15, s.closers))


func buy_clone(kind: String) -> bool:
	var cost := clone_cost(kind)
	if s.cash < cost:
		return false
	s.cash -= cost
	if kind == "scout":
		s.scouts += 1
	else:
		s.closers += 1
	changed.emit()
	save_game()
	return true


func training_cost() -> float:
	return 500.0 * pow(3.0, s.training)


func buy_training() -> bool:
	var cost := training_cost()
	if s.cash < cost:
		return false
	s.cash -= cost
	s.training += 1
	changed.emit()
	save_game()
	return true


func fund_cost() -> float:
	return 2000.0 * pow(4.0, s.funds - 1)


func buy_fund_slot() -> bool:
	var cost := fund_cost()
	if s.cash < cost:
		return false
	s.cash -= cost
	s.funds += 1
	changed.emit()
	save_game()
	return true


func stake_size() -> float:
	return maxf(100.0, floorf(s.cash * 0.25))


func invest() -> bool:
	if s.stakes.size() >= s.funds or s.cash < stake_size():
		return false
	var amount := stake_size()
	s.cash -= amount
	s.stakes.append({"amount": amount, "matures": now() + STAKE_TERM_S, "name": _startup_name()})
	changed.emit()
	save_game()
	return true


func _startup_name() -> String:
	var a := ["Nova", "Hyper", "Tiny", "Blue", "Quantum", "Lazy", "Night", "Solar", "Pocket", "Loud"]
	var b := ["Pizza", "Drones", "Ledger", "Robots", "Socks", "Bikes", "Tacos", "Mail", "Farms", "Cloud"]
	return a[randi() % a.size()] + " " + b[randi() % b.size()]


## Power law like real venture: most fail, one in two hundred pays for everything.
func roll_multiple(r: float) -> float:
	if r < 0.50: return 0.0
	if r < 0.80: return 1.5
	if r < 0.95: return 4.0
	if r < 0.995: return 12.0
	return 100.0


func collect_matured() -> Array:
	var results := []
	var keep := []
	for st in s.stakes:
		if float(st.matures) <= now():
			var m := roll_multiple(randf())
			var pay: float = float(st.amount) * m
			_earn(pay)
			s.best_exit = maxf(s.best_exit, m)
			results.append({"name": st.name, "multiple": m, "pay": pay})
		else:
			keep.append(st)
	s.stakes = keep
	if not results.is_empty():
		changed.emit()
		save_game()
	return results


func today() -> String:
	return Time.get_date_string_from_unix_time(int(now()))


func daily_available() -> bool:
	return s.claimed_day != today()


func daily_reward() -> float:
	var next := _next_streak()
	return 250.0 * next + earned_income_hour() * 0.5


func earned_income_hour() -> float:
	return income_per_s() * 3600.0


func _next_streak() -> int:
	var yesterday := Time.get_date_string_from_unix_time(int(now()) - 86400)
	return (s.streak + 1) if s.claimed_day == yesterday else 1


func claim_daily() -> float:
	if not daily_available():
		return 0.0
	var reward := daily_reward()
	s.streak = _next_streak()
	s.claimed_day = today()
	_earn(reward)
	changed.emit()
	save_game()
	return reward


func job_reward() -> float:
	var chain := mini(int(s.job_chain), 5)
	return (120.0 + income_per_s() * 30.0) * (1.0 + chain * 0.25)


func finish_job(success: bool) -> float:
	var pay := 0.0
	if success:
		pay = job_reward()
		_earn(pay)
		s.jobs_done += 1
		s.job_chain += 1
	else:
		s.job_chain = 0
	changed.emit()
	save_game()
	return pay


func find_clawn(id: int) -> String:
	if id in s.found:
		return ""
	s.found.append(id)
	_earn(250.0 + income_per_s() * 20.0)
	save_game()
	changed.emit()
	return FACTS[(s.found.size() - 1) % FACTS.size()]


func net_worth() -> float:
	var total: float = s.cash
	for st in s.stakes:
		total += float(st.amount)
	return total


func rank() -> String:
	var name := "Solo Founder"
	for r in RANKS:
		if s.earned >= r[0]:
			name = r[1]
	return name


## Index into RANKS, used by the tower that grows with your empire.
func rank_index() -> int:
	var idx := 0
	for i in RANKS.size():
		if s.earned >= RANKS[i][0]:
			idx = i
	return idx


func money(v: float) -> String:
	if v >= 1e9: return "$%.2fB" % (v / 1e9)
	if v >= 1e6: return "$%.2fM" % (v / 1e6)
	if v >= 1e4: return "$%.1fK" % (v / 1e3)
	return "$%d" % int(v)
