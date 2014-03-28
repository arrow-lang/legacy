# Some random unsafe block.
unsafe {  }

# Declare a mutable static.
static mut data_race: Atomic<int> = 0;

# Access the data_race.
unsafe {
    data_race += 21;
}
