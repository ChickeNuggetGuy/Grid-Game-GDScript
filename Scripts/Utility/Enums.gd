class_name Enums

enum unitTeam {NONE,PLAYER,ENEMY, ANY}

enum facingDirection {NONE,NORTH,NORTHEAST,EAST,SOUTHEAST,SOUTH,SOUTHWEST,WEST,NORTHWEST}

enum inventoryType {GROUND,BELT,BACKPACK,QUICKDRAW,RIGHTHAND,RIGHTLEG,LEFTHAND,LEFTLEG,MOUSEHELD}

enum cellState {
	NONE = 0,
	AIR = 1 << 0,        # 1
	GROUND = 1 << 1,     # 2
	EMPTY = 1 << 2,      # 4
	OBSTRUCTED = 1 << 3, # 8
	WALKABLE = 1 << 4    # 16
}


enum inventory_UI_slot_behavior {SELECT,EXECUTE_ACTION,TRY_TRANSFER}


enum UnitStance {
	NORMAL = 1 << 0,
	CROUCHED = 1 << 1,
	STATIONARY = 1 << 2,
	MOVING = 1 << 3}


enum FogState { UNSEEN, PREVIOUSLY_SEEN, VISIBLE }


enum ChangeTurnBehavior {NONE,MIN, MAX, INCREMENT, DERCREMENT }
