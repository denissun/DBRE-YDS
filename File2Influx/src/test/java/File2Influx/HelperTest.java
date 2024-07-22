package File2Influx;

import static org.hamcrest.CoreMatchers.containsString;
import static org.junit.Assert.*;

import org.junit.Test;

public class HelperTest {

  private Helper helper = new Helper();

  @Test
  public void greeterSaysHello() {
    assertThat(helper.sayHello(), containsString("Welcome"));
  }

}