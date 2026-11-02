extends SceneTree
## Headless economy test: godot --headless --path . -s scripts/econ_test.gd
func _init() -> void:
	var E = load("res://scripts/econ.gd").new()
	var fails := []
	var ok = func(c: bool, m: String): 
		print(("PASS " if c else "FAIL ") + m)
		if not c: fails.append(m)
	E.now_override = 1_000_000.0
	E.s = E.fresh()
	ok.call(E.buy_clone("scout"), "can afford first scout from start cash")
	ok.call(E.s.cash == 100.0, "scout costs 50")
	ok.call(E.buy_clone("closer"), "can afford first closer")
	ok.call(not E.buy_clone("closer"), "cannot overspend")
	ok.call(is_equal_approx(E.income_per_s(), 8.0), "1 scout + 1 closer = $8/s")
	for i in 600: E.tick(0.1)
	ok.call(absf(E.s.cash - 480.0) < 45.0, "60s of live ticks earns about $480, got %f" % E.s.cash)
	var c: float = E.s.cash
	E.now_override += 3600.0
	E.apply_offline()
	ok.call(is_equal_approx(E.s.cash, c + 28800.0), "1h away pays 1h income")
	c = E.s.cash
	E.now_override += 1000.0 * 3600.0
	E.apply_offline()
	ok.call(is_equal_approx(E.s.cash, c + 8.0 * 36000.0), "offline earnings capped at 10h")
	E.s.last_seen = E.now() + 5000.0
	c = E.s.cash
	E.apply_offline()
	ok.call(E.s.cash == c, "clock moved backwards pays nothing")
	var r: float = E.claim_daily()
	ok.call(r > 0.0 and E.s.streak == 1, "first daily claim")
	ok.call(E.claim_daily() == 0.0, "no double claim")
	E.now_override += 86400.0
	E.claim_daily()
	ok.call(E.s.streak == 2, "next day extends streak")
	E.now_override += 3.0 * 86400.0
	E.claim_daily()
	ok.call(E.s.streak == 1, "missed days reset streak")
	ok.call(E.invest(), "can back a startup")
	ok.call(not E.invest(), "fund slot limit holds")
	ok.call(E.collect_matured().is_empty(), "stake not paid early")
	E.now_override += E.STAKE_TERM_S + 1.0
	ok.call(E.collect_matured().size() == 1 and E.s.stakes.is_empty(), "stake pays after term")
	var total := 0.0
	for i in 200000: total += E.roll_multiple(float(i) / 200000.0)
	ok.call(absf(total / 200000.0 - 2.09) < 0.02, "exit EV about 2.09x")
	ok.call(E.find_clawn(1) != "" and E.find_clawn(1) == "", "Golden Clawn only pays once")
	E.free()
	print("RESULT: ", "OK" if fails.is_empty() else "FAILED %s" % str(fails))
	quit(0 if fails.is_empty() else 1)
