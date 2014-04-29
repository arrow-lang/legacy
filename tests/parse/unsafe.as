# Some random unsafe block.
unsafe {  }

# Declare a mutable static.
# static mut data_race: int = 0;

# Access the data_race.
unsafe {
    data_race += 21;
}
