# MinHeap.gd
extends RefCounted
class_name MinHeap

var heap: Array = []

func clear() -> void:
	heap.clear()

func size() -> int:
	return heap.size()

func is_empty() -> bool:
	return heap.size() == 0

func push(record: Dictionary) -> void:
	heap.append(record)
	_sift_up(heap.size() - 1)

func pop() -> Dictionary:
	if heap.size() == 0:
		return {}
	# remove root
	var result: Dictionary = heap[0]
	heap[0] = heap[heap.size() - 1]
	heap.pop_back()
	_sift_down(0)
	return result

func _sift_up(idx: int) -> void:
	while idx > 0:
		var parent_idx: int = (idx - 1) >> 1
		if heap[idx]["f"] < heap[parent_idx]["f"]:
			# swap heap[idx] and heap[parent_idx]
			var tmp = heap[idx]
			heap[idx] = heap[parent_idx]
			heap[parent_idx] = tmp
			idx = parent_idx
		else:
			break

func _sift_down(idx: int) -> void:
	var length: int = heap.size()
	while true:
		var left_idx:  int = (idx << 1) + 1
		var right_idx: int = left_idx + 1
		var smallest:  int = idx

		if left_idx < length and heap[left_idx]["f"] < heap[smallest]["f"]:
			smallest = left_idx
		if right_idx < length and heap[right_idx]["f"] < heap[smallest]["f"]:
			smallest = right_idx

		if smallest == idx:
			break

		# swap heap[idx] and heap[smallest]
		var tmp = heap[idx]
		heap[idx] = heap[smallest]
		heap[smallest] = tmp
		idx = smallest
